# Automated Puppet Compile Masters in Microsoft Azure

---

* *Please be ware that this is still in progress and will be covered in my Puppetconf 2017 talk in detail.* 

---

### What is all this ?

This document and associated code examples demonstrates how Puppet Enterprise, when deployed in Microsoft Azure, can benefit from a number of different services and capabilities, enabling more effective deployment and ongoing management, specifically in the compile master space.

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
1. Pregenerate all the compile masters keys and certs
2. Ensure you have a eyaml key created
3. Create a suitable service principal for the azure compile masters

    You can understand this in more detail via the following link :  [Create an Azure Active Directory application and service principal that can access resources.](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-create-service-principal-portal) 


4. Create a keyvault for all these secrets and other date
5. Populate the keyvault with all the secrets that we need in a predictable naming format
6. Ensure that the service principal for the compilemasters has suitable access to the keyvault containing our secrets and no other azure resources
7. Place the service principal credentials into another Azure Keyvault so we can pass them into ARM template deployments as parameters securely.
8. Ensure that node classification rules are in place for the trusted.certname of =~ compilemaster
9. Ensure that it also includes another module that handles pupeptserver gem installation for eyaml (Link coming soon).






### _Whats in this git repo ?_


This set of templates and code helps you understand how Puppet Compile masters can be deployed in Azure in a stateless fashion allowing them to be managed as cattle, rather than pets. 

This approach includes full support for compilemasters that use additional Puppetserver capabilities and gems such as hiera-eyaml.

This uses the following Puppet and Azure capabilities

 * [Puppet Enterprise 2017.x configured as an all in one master of masters](https://www.puppet.com)
 * [Azure Virtual Networking / Azure Virtual Machines &  Custom Script extensions](https://azure.microsoft.com/en-au/services/virtual-machines/)
 * [Azure Key Vault](https://azure.microsoft.com/en-au/services/key-vault/)
 * [Azure Resource Group Templates](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authoring-templates)
 * [The Azure Linux CLI v2](https://github.com/Azure/azure-cli)

### What should I know before getting this all working in my environment ?

There is quite a bit of moving parts in this topology, however it is relatively simple when you take it for a spin as long as you know the core components;

* Puppet Enterprise 2017.x
* Linux and Shell Scripting
* Azure - Specifically with ;
    * ARM Templates
    * Azure Virtual Networking & Virtual Machines
    * Azure Automation capabilities
    * Azure Service Principals
    * Azure Key Vault



You will also need to ensure that DNS is functioning accordingly in your deployments, and thus its out of scope in these examples. These examples assume the following.

* Domain: *.example.com
* Master of Masters: Puppetmaster.example.com
* Compilemasters: compilemaster0-40.example.com





















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
