# Automated Puppet Compile Masters in Microsoft Azure

---

* *The techniques covered in this repository will be covered in my [Puppetconf 2017 talk](https://puppetconf17.sched.com/event/B4wG/unlocking-azure-with-puppet-enterprise-keiran-sweet-sourced-group#).* 

---

### What is all this ?

This document and associated code examples demonstrates how Puppet Enterprise, when deployed in Microsoft Azure, can benefit from a number of different services and capabilities, enabling more effective deployment and ongoing management, specifically in the compile master space.

This uses the following Puppet and Azure capabilities;

 * [Puppet Enterprise 2017.x configured as an all in one master of masters](https://www.puppet.com)
 * [Azure Virtual Networking / Azure Virtual Machines &  Custom Script extensions](https://azure.microsoft.com/en-au/services/virtual-machines/)
 * [Azure Key Vault](https://azure.microsoft.com/en-au/services/key-vault/)
 * [Azure Resource Group Templates](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authoring-templates)
 * [The Azure Linux CLI v2](https://github.com/Azure/azure-cli)



### Compile Masters ? 


To quote the [Puppet documentation about scaling Puppet Enterprise by adding Compile masters](https://docs.puppet.com/pe/latest/install_multimaster.html);

| _As your infrastructure scales up to 4000 nodes and beyond, add load-balanced compile masters to your monolithic installation to increase the number of agents you can manage. Each compile master increases capacity by 1500 to 3000 nodes, until you exhaust the capacity of PuppetDB or the console, which run on the master of masters (MoM)._  |
| ------------- | 


An example deployment would look something like..;

![Example Architecture](https://github.com/keirans/azure-arm/blob/master/docs/img/Example_Architecture.png?raw=true)


This topology works well, however there are some challenges with building and managing compile masters that we would like to overcome to ensure that we can manage them more efficiently (less like pets), they are:

* Compile masters need a special type of node-specific certificate to allow them to accept connections from agents in the fleet and authorise themselves as a trusted actor within the Puppet deployment, however for security reasons, You cannot currently use policy based autosigning like you would a normal node to authorise these types of nodes and certificate types, this provides a bit of a barrier when it comes to automating them effectively. (See [SERVER-1005](https://tickets.puppetlabs.com/browse/SERVER-1005) for more information.)


* Compile masters often require additional secrets to be transferred to the node to allow it to decrypt values that are stored in hiera when additional features such as hiera-eyaml is used. Due to the sensitive nature of these private keys (They allow decryption of your sensitive hiera data), they are often manually transferred to the compile master at build time from a secrets repository.


* Puppet Enterprise Patching and OS upgrades of compile masters can often be arduous, we want to get to a position in which these nodes can be easily disposed of, and then redeployed in an updated state. No more SSH + YUM + Puppet upgrade scripts.


### _So, TL;DR ?_

_We want to make our compile masters be as disposable as possible, reducing the overhead of their management, while improving reliability, scalability and security_


### _So how are we going to do this ?_

![Puppet Azure Architecture](https://github.com/keirans/azure-arm/blob/master/docs/img/azure_compilemaster_components.png?raw=true)

The approach is as follows:

1. An Azure ARM template deploys a set of compile master virtual machines. Nested templates are used to create multiple copies of a single compile master template. 
Each compile master instance is named compilemasterX, where X is a unique instance ID passed down from the nested template.


2. On launch, each instance fetches and executes a compilemasterbootstrap.sh script from a git repostory over HTTPS.


3. The bootstrap script takes a set of Azure API credentials as parameters. These credentials are fetched from Azure Keyvault on deploy to ensure that they are stored and used securely.


4. When the script executes on the instance, it installs a set of required software components on the host including python and the Azure CLI.

5. The Azure CLI then uses the credentials passed into the script to login to the Azure CLI and retreive the following precreated secrets that it requires from the Puppet secrets keyvault.

    * The Compile Masters pre-created private key
    * The Compile Masters pre-created public key
    * The Compile Masters pre-created certificate
    * The Puppet deployments CA public cert
    * The sites eyaml private key (For allowing it to decrypt hiera secrets)

As each compile master instance is named compilemasterX, where X is a unique instance ID passed down from the nested template, they are able to identify and retreive their appropriate keys and certs accordingly.

6. Once the secrets have been downloaded and placed on the instance in the required locations, the instance logs out of the Azure API as there is no need for it to have access any longer.

7. The node installs Puppet via the install.bash script fetched directly from the Master of Masters. Because we have already provided a pre-signed cert for this host, it is automatically authorised and classified by the Puppet Master of Masters as a Puppet Master by assigning it to the Puppet Master node group.

8. The script then waits for up to 10 minutes for the initial Puppet runs to complete (We run a few extras) to ensure that is green in the console. They are then available for service.




### _Puppet Master Configuration Steps_

1. Pregenerate all the compile masters keys and certs and store them in a keyvault for retreival.

      What you may not be aware of is that you can pre-create all the certs for the compile masters on the master of masters (or the host that is your CA) and then transfer them to the instance rather than do it from the Puppet agent directly. In doing this, you can use the --dns_alt_names option as required.
  
      As an example, you can have a look at the script "generate_certs.sh" in this repository that shows how we can create a keyvault in Azure, generate 40 compile master keys and certs and then store them in the keyvault so they can be retreived by a compile master when they are bootstrapped.
  
      Don't forget that the service principal credentials that are passed into the bootstrap script needs to have access to this key vault resource in order to be able to access these keys and certs.


2. Ensure you have a eyaml key created and place that in the Puppet secrets keyvault

    If you are using hiera-eyaml, make sure you also upload the private key (or keys) to the file vault as well. Each compile master needs to have this present to be able to disable encrypted hiera secrets.
    
    If you look at the "generate_certs.sh" file, you will see that it also checks for the presence of this file and uploads it into the key vault with the name "eyamlprivate"


3. Create a suitable service principal for the azure compile masters

    Because Azure doesnt have the concept (yet) of AWS IAM instance roles, we need to create a service principal for the compile masters that has access to the Keyvault that contains all the compile master secrets.

    You can understand this in more detail via the following link :  [Create an Azure Active Directory application and service principal that can access resources.](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-create-service-principal-portal) 

    Once you have created the service principal, you should place these credentials into another, seperate key vault that is used to pass secrets into the compile master deployments. (Platform Keyvaul in the above diagrams)


4. Ensure that node classification rules are in place for the compile masters

    To ensure that the when a compile master requests a catalogue from the master of masters, it is classified correctly, you need to add a node classifier rule that places instances with a trusted.certname that begins with compilemaster*.example.com into the Puppet Masters node group, esuring that the instances are configured correctly.

    To ensure that the compile masters install additional gems such as the eyaml gem into the Puppet server, you will need to add an additional class to the Puppet Master node group that configures them. A sample manifest for this is stored in this git repository for your reference.



### _Whats in this git repo ?_


This set of templates and code helps you understand how Puppet Compile masters can be deployed in Azure in a stateless fashion allowing them to be managed as cattle, rather than pets. 

This approach includes full support for compilemasters that use additional Puppetserver capabilities and gems such as hiera-eyaml.


You will also need to ensure that DNS is functioning accordingly in your deployments, and thus its out of scope in these examples. These examples assume the following.

* Domain: *.example.com
* Master of Masters: Puppetmaster.example.com
* Compilemasters: compilemaster0-40.example.com


_Repository components_ 

* Base

  - A sample ARM template that builds a set of subnets in a VNET and the example parameters for the network.
  

* Servers

    - A sample set of ARM templates that show how a set of compile masters can be deployed and bootstrapped from a central master of masters as detailed in this document. 

    - A single instance template that was used for the initial build of the master of masters.


* Docs
    * This document 


* manifests
    * A set of manifests that are useful for seeing how we can configure the compile masters to be fully functional in an automated fashion. In this case, a class that installs the hiera-eyaml gem into the puppet server on a compile master.


* scripts
    * A set of scripts that demonstrate how to setup the compile master certs and store them in an Azure keyvault, as well as a sample bootstrap script that shows how we can retreive them and bootstrap compile masters that gives us a fully functional, automated compile master without human interaction.



### _The Result_

The below screenshots show what we will see in the Puppet console when deploying 2, then 4 compile masters in this manner.

* Before the deployment begins - A single Master of Masters - Puppetmaster.example.com

![Single Puppetmaster](https://raw.githubusercontent.com/keirans/azure-arm/master/docs/img/Single_Master.png)


* After the initial deployment we have 2 new Puppetmasters that have run and reported change. They arent showing up via the service API just yet however.

![Bootstrapping Puppetmasters](https://raw.githubusercontent.com/keirans/azure-arm/master/docs/img/Compile_Masters_Bootstrap.png)

* The Puppet Master of Masters then checks in and configures the environment with the new ready compilemasters. The Status API reports they are all online and functioning now.


![Bootstrapping Puppetmasters](https://raw.githubusercontent.com/keirans/azure-arm/master/docs/img/Compile_Masters_Online.png)

* Additional capacity is only a redeploy away after incrementing the compile master count parameter in an ARM template.


![Bootstrapping Puppetmasters](https://raw.githubusercontent.com/keirans/azure-arm/master/docs/img/Additional_compilemaster_capacity.png)



### _Use cases_
Now that we know that we can do this, what does this enable us to do ?

* Rapid deployment of compile masters in scale out scenarios

  We can rapidly build compile masters when need arises, such as adding new compile masters, and they will be quickly be brought into service and configured identically.
  
  
* Rapid OS patching of compile masters via teardown and redeployment

    Rather than install OS patches in place, one by one, tear down all the compile masters and then redeploy them using an updated OS baseline. The instances will then all reinstall Puppet on build and be configured as required. A roll back will be as simple and tearing down the build and redeploying with the previous version.

* Rapid Puppet patching of compile masters via teardown and redeployment

    Rather than install Puppet patches in place,one by one, tear down all the deployed Puppet compile masters, patch the Puppet master of masters, then redploy all the compile masters. In doing this, the Puppet compile masters will be built using the latest Puppet software exposed by the master of masters, your new compile masters will have the same identities, but their software will be at the latest versions.
    
    

