# OutSystems-CollectInfo-wdocker

In this project you can find 2 main scripts:
* CollectInfo.ps1

Script that gathers troubleshooting information from the host machine and the container. This script was built to run on Windows machines running Windows containers.

Running the script will generate two folders: one named `Container` that will have all the information collected from the container; another one named `Host` that will have all the information from the hosting machine. In the end we will archive all the information in a ZIP file.

* CollectDump.ps1

Script that collects a memory dump file of an OutSystems container application. This script was built to run on Windows machines running Windows containers.
This script depends on an external tool Procdump (https://docs.microsoft.com/en-us/sysinternals/downloads/procdump) from Microsoft.

## How to use

### Before you use the script

**The script assumes that you have access to the machine that is hosting the container.**

For `CollectInfo`:

Create a folder and download the file [CollectInfo](CollectInfo.ps1) or all the files in the `scripts` folder into it.

For `CollectDump`:
1. Create a folder and download the file [CollectDump](CollectDump.ps1)
1. Download [Procdump]( https://docs.microsoft.com/en-us/sysinternals/downloads/procdump ) tool and put the zip file next to the `CollectDump.ps1` file.

Now you will need to gather information to run the script.

Get the ID of the container we want to troubleshoot (we will refer to it as *&lt;containerId&gt;*). To do this, in PowerShell run:

```
docker ps -a
```

Next, you will need the name of the site bound to the container (we will refer to it as *&lt;siteName&gt;*). To do this, in PowerShell run:

```
get-website
```

You will need to list the endpoints you want to test connectivity to from inside the container (we will refer to this list as *&lt;host:port[]&gt;*). Make sure you include in this list at least the endpoint of the database and the endpoint of the controller. If you have integrations in your application, it's a good idea to test them also.

You can get the database endpoint using OutSystems Configuration Tool. In the Platform tab, you will see a *Server* input — copy this value. The database port is usually 1433. The controller endpoint is in the Controller tab: check the *Deployment Controller Server* and *Deployment Controller Service Port* inputs.

### Running the script

Run the script in PowerShell:

```
.\CollectInfo.ps1 -ContainerId <containerId> -SiteName <siteName> -Hosts <host:port[]>
```

```
.\CollectDump.ps1 -ContainerId <containerId>
```

Example:

```
.\CollectInfo.ps1 -ContainerId 40f93371dbfa -SiteName "Default Web Site" -Hosts dbserver.outsystems.net:1433,controllerserver.outsystems.net:12000
```

* &lt;containerId&gt;
The Id of the container we want to collect information from
* &lt;siteName&gt;
The name of the site configured in IIS
* &lt;host:port[]&gt;
A list of tuples of `hostname:port`. The script will test the connectivity to these hosts from inside the container.

```
.\CollectDump.ps1 -ContainerId 40f93371dbfa
```

* &lt;containerId&gt;
The Id of the container we want to collect information from

## Change the scripts

If you need to edit the scripts, edit the files inside the `scripts` folder. The `CollectInfo.ps1` script is a merge of all the scripts and models present in the `scripts` folder; this single file exists just for convenience.

### Build

```
TODO: Merging all scripts and modules in a single file
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
