# Demoing Servermonitor

## Presentation for the Singapore PowerShell User Group - Summer 2017

### History

Created in 2007 as one of my first larger PowerShell scripts, evolved over time

### Demo

    (New-Object System.Net.WebClient).DownloadFile('https://github.com/hahndorf/ServerMonitor/archive/master.zip',"$pwd\ServerMonitor.zip")
    Expand-Archive -Path .\ServerMonitor.zip -DestinationPath .
    cd ServerMonitor-master
    ls
    mv .\Example.xml .\ServerMonitor.xml
    .\ServerMonitor.ps1
    n $pwd\ServerMonitor.xml

enable foldersize, change path to '%bindir%' and 1MB

     .\ServerMonitor.ps1
     .\ServerMonitor.ps1 -verbose

### Providers and Loggers

Show the available providers and loggers

https://peter.hahndorf.eu/tech/servermonitor.html#basics

https://peter.hahndorf.eu/tech/servermonitor.html#Loggers

### How did I implement extensions

Show how dropping a new file into the directory is enough
Show the code and talk about dot sourcing

### Create a new provider

lets create a new simple provider

"# dummy " | Out-File -FilePath $pwd\smpNic.ps1 -Encoding ascii

ise $pwd\smpNic.ps1

    function CheckNic()
    {
        if ($global:ConfigXml.servermonitor.SelectNodes("nic").count -ne 1) 
        {
            ShowInfo "nic node not found"
            return
        }

        $global:ConfigXml.servermonitor.nic.check |
        ForEach {
            $name = $_.GetAttribute("name");
            if ((Get-NetAdapter | Where Name -eq "$name").Name -ne "$name"){
                AddItem -info "Nic: $name not found" -Source "Nic Checker" -EventId $smIdUnexpectedResult -EventType "Warning"   
            }          
        }           
    }

  n $pwd\ServerMonitor.xml

    <nic>
       <check name="Ethernet" />
       <check name="LanCard" />
    </nic>

### Links

https://github.com/hahndorf/ServerMonitor