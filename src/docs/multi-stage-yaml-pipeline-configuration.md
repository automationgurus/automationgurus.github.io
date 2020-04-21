# Multi-Stage YAML Pipeline Configuration

![Multi-Stage YAML pipeline]()

Since May 2019 Microsoft offer as a part of Azure DevOps service Multi-Stage YAML pipelines.
Probably you will ask what is a difference between standard approach of CICD process and Multi-Stage?
Answer is pretty simple - in standard approach only CI (build) part of CICD process was possible to define as YAML definition.
Multi-Stage YAML pipelines (name of it is bacially self explanatory) approach allows to define both CI (build) and CD(release) processes in YAML language.

## Ok, but why I should use it if I can easly click everything in portal?

Of course you can do everything via GUI, but common why not take one step forward and define your pipeline as a code?
How cool it can be if you are defining not only infrastructure as a code but also your whole CICD process?

If I didn't encourage you yet to using this funcionality, below you can find more advantages of using it:

- **Diff option** - you can compare the definition which are failing with the last known good configuration.
  
- **History** - source control allows you to see every change which was done to your pipeline since the initial creation.
  
- **Rollback** - if you found that your last commit causing any problem during deployment, simple roll it back to last good configuration.
  
- **Reusability option** - how often you wanted to reuse pipeline which is already defined? - now you can simply do that by copy/paste option.

- **Team cooperation** - if there are multiple people working on same pipeline it can cause problem using GUI, using YAML team members can work on separate branch and adjust definition according to their needs.

## Sounds good, but what if I don't have experience with YAML language?

If you think it is problem you are totally wrong.
YAML is not complicated - if you ever define Azure resource definition using Azure Resource Manager (ARM template) you will for sure be able to easily write YAML pipelines.

<PICTURE OF YAML>

## How to get started with Multi-Stage YAML pipelines?

Let me guide you step by step how to configure such pipeline.

In my example I will show you how to configure Azure Kubernetes Service with some additional tools which are usefull during application deployment.

Later you can adjust it to your needs by changing specific task - however overall process of creation will be basically the same.

### Prerequisites

In my scenario as a prerequisites AKS clusters should be created

![AKS-Clusters](img/multi-stage-yaml-pipeline-configuration-002.jpg)