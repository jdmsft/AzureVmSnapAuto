# Azure VM Snapshot Automation

Create / Remove Azure Virtual Machine snapshot with Azure Automation

## Getting Started

These instructions will show you how to use this code as a runbook in Azure Automation. 

## Prerequisites

In order to use this module you need to use import AzureRM [Automation Module](https://docs.microsoft.com/en-us/azure/automation/shared-resources/modules).


## How to use this runbook

* Copy content from __vmSnapshotAutomation.ps1__ to an Azure Automation Runbook.
* Schedule job to run this runbook on a daily-basis for example.
* Set RetentionDays parameter to your needs to automatically remove old VM snapshots object from Azure.


_This script / runbook call be call in the following PowerShell command :_  

```
.\vmSnapshotAutomation.ps1 -RetentionDays 7
```


## Built With

* [Visual Studio Code](https://code.visualstudio.com/)
* [GitHub](https://github.com/jdmsft)


## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/jdmsft/PSFileShare/tags). 

## Authors

* **Jessy DESLOGES** [@jdmsft](https://github.com/jdmsft)

See also the list of [contributors](https://github.com/jdmsft/PSFileShare/contributors) who participated in this project.