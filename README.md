# OutSystems-CollectInfo-wdocker

Script that gathers troubleshooting  information from host machine and container. This script was build to run on Windows machines running Windows containers.

Running the script will generate two folders. One named Container that have all the information collected from the container. Another name Host that have all the information form the hosting machine. At the end he archive all the information in a zip file.

## How to use

### Before you use the script

**The script assumes that you have access to the machine that is hosting the container.**

First create a folder and download the file [CollectInfo](CollectInfo.ps1) or all the files in the scripts folder into it.

Now you will need to gather information to run the script.

You will need to the ID of the container we want to troubleshoot. We will refer to it as *<containerId>*. To do this at a powershell run

```
docker ps -a
```

Next, you will need the name of the site bonded to the container. We will refer to it as *<siteName>*. To do this at a powershell run

```
get-website
```

You will need to list a set of endpoints you want to test connectivity from inside the container. We will refer to it as *<host:port[]>*. Include in this list at least the endpoint of the database and the endpoint of the controller. If you have integrations in your application, it's a good idea to test them also.

You can get the database endpoint at  OutSystems's configuration tool. Under the Platform tab, you will see a  *Server* input, copy this value. The database port is usually 1433. The controller endpoint is on the Controller tab. There you will see *Deployment Controller Server* and *Deployment Controller Service Port*.

![Configuration Tool](https://www.outsystems.com/PortalTheme/NewOSLogoRed.svg)

### Running the script

To run the script in a powershell do

```
.\CollectInfo.ps1 -ContainerId <containerId> -SiteName <siteName> -Hosts <host:port[]>
```

You can see an example bellow

```
.\CollectInfo.ps1 -ContainerId 40f93371dbfa -SiteName "Default Web Site" -Hosts dbserver.outsystems.net:1433,controllerserver.outsystems.net:12000
```

* <containerId>
** The Id of the container we want to collect information from
* <siteName>
** The name of the site configured at the IIS
* <host:port[]>
** A list of tuples of hostname:port. The script will test the connectivety to this hosts from inside the container.

## Change the scripts

If you need to edit the scripts edit the files inside the scripts folder. The CollectInfo.ps1 script is a merge of all scripts and models present in the scripts folder. We have the single file for convenience reasons.

### Build

```
TODO: Merging all scripts and modules in a single file
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details