# Vault on AWS via Terraform

This module will allow you to publish vault on your own AWS infrastructure using docker. Why another module? We needed something that will let us build out everything using docker rather then provision an initial ami. This is a bit different than the current module that's available (don't get us wrong, it's great) so we built this. It's a very straightforward deploy and will work in enterprise or startup situations. Proper networking design is left up to the reader.

Currently we support the following features:

1. Docker based deployment. The module uses the most recent AWS Linux 2 AMI for deployment and runs vault inside containers in those instances. No binary installs here.
2. Configurable number of workers and webs along with volume sizes and instance types. Everything has a sane default but customize to your liking.

See the examples directory for more information on how to deploy this to your account. You shouldn't need to this very much. Check `variables.tf` for information on all the bits you'll need and also see the `main.tf` in the root directory for an example of how to call the module.

## Prerequisites

First, you need a decent understanding of how to use Terraform. [Hit the docs](https://www.terraform.io/intro/index.html) for that. Then, you should understand the [vault architecture](https://www.vaultproject.io/docs/internals/architecture.html). Once you're good import this module and pass the appropriate variables. Then, plan your run and deploy.

## Vault HA Architecture

Vault is irritating to work with when placed in a cluster, but this is more or less by design. Vault utilizes a hot-standby approach and doesn't scale horizontally through new nodes. So, any time you build out a vault cluster you need to understand that you'll be performing the following steps by *hand* every time. We recommend only ever creating a single standby node. That's more or less all you'll need.

When vault starts up behind the load balancer the health check will report that all nodes are unhealthy by default. The `sys/health` API returns a 503 when the node is in an uninitialized state. To allow users to initialize the vault cluster via the ui we modify the health check to return a 200 when vault is in this state (see the health check for the vault target group in `lb.tf` for more details).

First, you must initialize a vault cluster. To do so log into a machine with the vault client installed and run `vault operator init` with the appropriate values selected, or you can hit the load balancer provisioned through this terraform and initialize it via the UI. The master key will be written to the backend storage and propagated to all other nodes, so you don't need to perform that operation more than once.

Next is unsealing--which is the irritating part. You must unseal *every node* in your cluster distinctly. We *do not* recommend attempting to do this via the load balancer because it will be very painful. Instead, hit the private IP address of each node and unseal it via the UI or run the appropriate `unseal` command on the CLI for every node.

### Failing over

Hopefully in the future vault will have some more interesting ways to manage this problem, but currently the way we fail over is via health checks on the target groups. The [api documentation](https://www.vaultproject.io/api/system/health.html) for the health check API is very good, and to understand the solution you should read the documentation and note that through query string parameters we can control how the health check API responds to specific vault states.

## Vault AppRoles

To allow Vault access for machines and services an AppRole is required. To do this you must first generate a secret_id and a role_id. This four step process will use your Initial Root Token to generate both of these IDs. Once generated, the IDs must then be used in your setup process to allow your machines/services to access Vault.

For eaxmple: we pass this to our Concourse `cred_store_var` to enable integration: 

1. Enable the AppRole auth method:
```sh
$ curl \
    --header "X-Vault-Token: <YOUR_INITIAL_ROOT_TOKEN_HERE>" \
    --request POST \
    --data '{"type": "approle"}' \
    https://<YOUR_URL_HERE>/v1/sys/auth/approle
```
2. Create an AppRole with desired set of policies:
```sh
$ curl \
    --header "X-Vault-Token: <YOUR_INITIAL_ROOT_TOKEN_HERE>" \
    --request POST \
    --data '{"policies": "default"}' \
    https://<YOUR_URL_HERE>/v1/auth/approle/role/my-role
```
3. Fetch the identifier of the role:
```sh
$ curl \
    --header "X-Vault-Token: <YOUR_INITIAL_ROOT_TOKEN_HERE>" \
    https://<YOUR_URL_HERE>/v1/auth/approle/role/my-role/role-id
```
The response will look like:
```sh
{
  "data": {
    "role_id": "988a9dfd-ea69-4a53-6cb6-9d6b86474bba"
  }
}
```
4. Create a new secret identifier under the role:
```sh
$ curl \
    --header "X-Vault-Token: <YOUR_INITIAL_ROOT_TOKEN_HERE>" \
    --request POST \
     https://<YOUR_URL_HERE>/v1/auth/approle/role/my-role/secret-id
```
The response will look like:
```sh
{
  "data": {
    "secret_id_accessor": "45946873-1d96-a9d4-678c-9229f74386a5",
    "secret_id": "37b74931-c4cd-d49a-9246-ccc62d682a25"
  }
}
```
## Architecture

This is a fairly minimal install that should plug into any AWS architecture. We crafted the security groups such that only the appropriate traffic sources are able to hit specific targets. You can see this by deploying the module and inspecting the SGs, or looking at the appropriate section of the ```main.tf```.
