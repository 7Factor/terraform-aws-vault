# Vault on AWS via Terraform

TODO: update this file

This module will allow you to publish vault on your own AWS infrastructure using docker. Why another module? We needed something that will let us build out everything using docker rather then provision an initial ami. This is a bit different than the current module that's available (don't get us wrong, it's great) so we built this. It's a very straightforward deploy and will work in enterprise or startup situations. Proper networking design is left up to the reader.

Currently we support the following features:

1. Docker based deployment. The module uses the most recent ECS AMI for deployment and runs vault inside containers in those instances. No binary installs here.
2. Configurable number of workers and webs along with volume sizes and instance types. Everything has a sane default but customize to your liking.
3. Requires AWS application load balancing complete with SSL termination. We may upgrade this in the future, but it works fine. Why bother?
4. Inherits the current AWS region from parent modules.

See the examples directory for more information on how to deploy this to your account. You shouldn't need to this very much. Check ```variables.tf``` for information on all the bits you'll need and also see the ```main.tf``` in the root directory for an example of how to call the module.

## Prerequisites

First, you need a decent understanding of how to use Terraform. [Hit the docs](https://www.terraform.io/intro/index.html) for that. Then, you should understand the [vault architecture](https://www.vaultproject.io/docs/internals/architecture.html). Once you're good import this module and pass the appropriate variables. Then, plan your run and deploy.

Not much can go wrong here, but [file issues](https://github.com/7Factor/7f-vault/issues) as needed. Be sure to read our [issues guide](https://7factor.github.io/7fpub-ghissues/) before hand. PRs are welcome.

## Architecture

![architecture](https://raw.githubusercontent.com/7Factor/7f-vault/dev/docs/vault.png)

This is a fairly minimal install that should plug into any AWS architecture. We crafted the security groups such that only the appropriate traffic sources are able to hit specific targets. You can see this by deploying the module and inspecting the SGs, or looking at the appropriate section of the ```main.tf```.