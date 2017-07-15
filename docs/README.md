# Automated Puppet Compile Masters in Azure

This is still in progress and will be covered in my Puppetconf 2017 talk in detail. Stay tuned for more updates.

This set of templates and code helps you understand how Puppet Compile masters can be deployed in Azure in a stateless fashion allowing them to be managed as cattle, rather than pets. 

This approach includes full support for compilemasters that use additional Puppetserver capabilities and gems such as hiera-eyaml.

This uses the following Puppet and Azure capabilities

 * Puppet Enterprise 2017.x configured as an all in one master of master
 * Azure Virtual Networking
 * Azure Virtual Machines + Custom Script Extensions
 * Azure Key Vault
 * Azure Resource Group Templates
 * The Azure Linux CLI v2

What should I know before getting this all working in my environment

* Linux (RHEL in this case) and Shell Scripting
* Puppet Enterprise
* Azure - Specifically with ARM Templates, VMs, Automation, Service Principals and Key Vault. There is quite a bit of moving parts in this topology, however it is relatively simple when you take it for a spin.


How does this all work ?

Puppet Master Configuration Steps
1. Pregenerate all the compile masters keys and certs
2. Ensure you have a eyaml key created
3. Create a suitable service principal for the azure compile masters
4. Create a keyvault for all these secrets and other date
5. Populate the keyvault with all the secrets that we need in a predictable naming format
6. Ensure that the service principal for the compilemasters has suitable access to the keyvault containing our secrets and no other azure resources
7. Place the service principal credentials into another Azure Keyvault so we can pass them into ARM template deployments as parameters securely.
8. Ensure that node classification rules are in place for the trusted.certname of =~ compilemaster
9. Ensure that it also includes another module that handles pupeptserver gem installation for eyaml (Link coming soon).


Compile Master Deployment process

1. An Azure ARM template deploys a set of compile master virtual machines that fetch and execute a compilemasterbootstrap.sh script.


2. The bootstrap script takes a set of Azure API credentials as parameters. These credentials are fetched from Azure Keyvault on deploy to ensure that they are stored securely.


3. When the script executes on the instance, it installs a set of required software components on the host including python and the Azure CLI.

4. The Azure CLI then uses the credentials passed into the script to login to the Azure CLI and retreive the following precreated secrets that it requires.

    * The Compile Masters pre-created private key
    * The Compile Masters pre-created public key
    * The Compile Masters pre-created certificate
    * The Puppet deployments CA public cert
    * The sites eyaml private key (For allowing it to decrypt hiera secrets)

5. Once the secrets have been downloaded and placed on the instance in the required locations, the instance logs out of the Azure API as there is no need for it to have access any longer.


6. The node installs Puppet via the install.bash script fetched directly from the Master of Masters.


7. The script then waits for up to 10 minutes for the initial Puppet run to complete, then Runs Puppet 2 more times for good measure to ensure that all is green in the console.



The Result

* Before the deployment - A single Master of Masters - Puppetmaster.example.com

![Single Puppetmaster](https://raw.githubusercontent.com/keirans/azure-arm/master/docs/img/Single_Master.png)



* After the Deployment we have 2 new Puppetmasters that have run and reported change. They arent showing up via the service API however.

![Bootstrapping Puppetmasters](https://raw.githubusercontent.com/keirans/azure-arm/master/docs/img/Compile_Masters_Bootstrap.png)

* The Puppetmaster checks in and configures the environment with the new ready compilemasters. The Status API reports they are all online and functioning.


![Bootstrapping Puppetmasters](https://raw.githubusercontent.com/keirans/azure-arm/master/docs/img/Compile_Masters_Online.png)

