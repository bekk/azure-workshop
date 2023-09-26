# Azure workshop

This workshop gives an introduction to Microsoft Azure with [Terraform](https://www.terraform.io/). It will guide you through creating a web app serving an API in a container, a database for the API, a frontend connecting to the API and DNS. Optional tasks at the end guide you through setting up HTTPS, virtual networking, and more.

*Note:* The DNS parts of the workshop requires some extra resources for custom domain names managed by the workshop facilitators. If you are working through this workshop on your own, you will have to set up your own DNS zone with a custom domain name. You will also need to get access or sign up to Azure on your own.

## Getting started

### Required tools

For this workshop you'll need:

* Git
* [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
* [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

Optionally, for optional tasks:

* [k6](https://k6.io/docs/get-started/installation/)

On macOS, with `brew`, you can run `brew install azure-cli terraform k6`

### Authenticating in the Azure portal

1. You will receive access to Azure. Depending on where the workshop is run, you might have received credentials from a workshop facilitator or received an email with a signup link that gives you access.

2. Log in to the Azure Portal. Go to [portal.azure.com](https://portal.azure.com) and log in.

3. In the portal, verify that you're logged in to the "Bekk Terraform Workshop" tenant in the top-right corner.

    ![](img/bekk-terraform-workshop-profile.png)

    1. If you're signed in with a different/user email, click your profile image, then "Sign in with a different account". Log in with the correct email/credentials.

    2. If you're in another tenant, click your profile image, then "Switch directory" and then choose "Bekk terraform workshop" on the next page.

    3. If you don't have access when logging in with an email account, please find the email sent to you and click the signup link. If you still can't sign in to the correct tenant, ask a workshop facilitator.

### Authenticating with the Azure CLI

1. Run `az login`. A browser should open and initiate a sign-in process.

2. Run `az account show` to verify that you're successfully logged in, and that you're connected to the `iac-workshop` subscription. If you're not connected to the correct subscription, run `az account set -s iac-workshop` to change subscription, followed by `az account show` to verify.

## Terraform

This repository has two folders for this workshop: `frontend_dist/` contains some pre-built frontend files that we'll upload and `infra/` will contain our terraform code. All files should be created here, and all terraform commands assume you're in this folder, unless something else is explicitly specified.

The `infra/` folder, does not contain many files yet:

* `terraform.tf` contains *provider* configuration. A provider is a plugin or library used by the terraform core to provide functionality. The `azurerm` we will use in this workshop provides the definition of Azure resources and translates to correct API requests when you apply your configuration.

Let's move on to running some actual commands 🚀

1. Before you can provision infrastructure, you have to initialize the providers from `terraform.tf`. You can do this by running `terraform init` (from the `infra/` folder!).

    This command will not do any infrastructure changes, but will create a `.terraform/` folder, a `.terraform.lock.hcl` lock file. The lock file can (and should) be committed. :warning: The `.terraform/` folder should not be committed, because it can contain secrets.

2. Create a `main.tf` file (in `infra/`) and add the following code, replacing `<myid523>` with a random string containing only lowercase letters and numbers, no longer than 8 characters. The `id` is used to create unique resource names and subdomains, so ideally at least 6 characters should be used to avoid collisions.

    ```terraform
    locals {
      id = "<yourid42>"
    }

    resource "azurerm_resource_group" "todo" {
      name     = "rg-todo-${local.id}"
      location = "West Europe"
    }
    ```

    The code above creates a *resource group*. An Azure resource group used to group resources that belong together. The resource group is created in the "West Europe" Azure region, and will be named `rg-todo-<yourid42>`.

    The `locals` block defines a local variable. Local variables can be defined and used anywhere in a terraform module, so `local.id` can be referenced in other files you create too.

4. Run `terraform apply`. Take a look at the output: terraform will refresh the real-world state, then give an overview of which changes will be done. In this case, creating a resource group. Write `yes`, when terraform asks whether you want to continue.

5. Go to the [Azure portal](https://portal.azure.com/) and verify that you can find your resource group. Using the search bar at the top might be the quickest way to find it.

## Backend

The backend is a pre-built Docker-image uploaded in the GitHub package registry. We'll run it using an Azure Web App that pulls the image and runs it as a container.

Azure App Service backs many different services: Web Apps, Logic Apps, Function Apps and more. An app service plan is an abstraction for the underlying hardware, and manages file system storage, operating system, networking, vertical scaling (more memory/cpu) and horizontal scaling (parallelization). Multiple apps can run on a single app service plan, sharing the resources.

Web app is a representation of a web application. It manages app settings (environment variables), authentication, identity, custom domains, CORS, and deployment, in addition to app-specific networking rules.

1. Create a new file, `backend.tf`. 

2. We'll create a new resource of type `azurerm_service_plan`, named `sp-todo-<yourid42>`. Like this:

    ```terraform
    resource "azurerm_service_plan" "todo" {
      name = "sp-todo-${local.id}"

      resource_group_name = azurerm_resource_group.todo.name
      location            = azurerm_resource_group.todo.location

      sku_name = "B1"
      os_type  = "Linux"
    }
    ```

    Note that the terraform local name (here: `todo`) does not need to be the same as the Azure resource name `sp-todo-<yourid42>`. Also note that the local name of the service plan and the resource group we created previously are the same. Both can be named `todo`, since we have to reference them by prefixing with the type (i.e., `azurerm_resource_group.todo.name` gets the resource group name).

    In order to avoid rewriting all files when we want our app in a different location, we're going to refer to the resource group location. It is a well-established practice, and also beneficial for networking latency, to provision all resources in the same region. 

    The `sku_name` variable defines the vertical scaling, and also the price of the app service plan. At the time of writing, `B1` corresponds to 1 CPU core and 1.75GB RAM for 13.140 USD/month. Take a look at the [pricing page](https://azure.microsoft.com/en-us/pricing/details/app-service/linux/) for more information.

3. Run `terraform apply` and verify that it's created correctly in the portal.

4. The web app will be created similarly. Notice that we have to reference the `id` of the service plan we just created, to connect the web app to the app service plan.

    ```terraform
    resource "azurerm_linux_web_app" "todo" {
      name = "app-todo-${local.id}"

      resource_group_name = azurerm_resource_group.todo.name
      location            = azurerm_resource_group.todo.location
      service_plan_id     = azurerm_service_plan.todo.id

      https_only = false


      site_config {
        application_stack {
          docker_image_name   = "bekk/k6-workshop-todo-backend:latest"
          docker_registry_url = "https://ghcr.io"
        }
      }
    }
    ```

5. When running `terraform apply` the Web App will be created and pull the image specified in the `application_stack` block. Go into the Azure portal, find the web app and find "Log stream" in the "Monitoring section of the left hand menu. Using the search at the top of the sidebar makes it quicker to find the menu item.

    ![](img/web-app-log-stream.png)

    The log stream should show that the image was pulled, but that the `DATABASE_URL` was not defined when the image started. We haven't created a database yet, so we'll get back to that.

## Database

The most commonly used database in Azure is the Azure SQL database, which is a SQL Server-based database. Azure also has Postgres, MySQL and other offerings, but the Azure SQL offering is more mature and generally easier to work with in Azure.

To provision a database, we'll first have to provision an SQL server resource. The SQL server manages the firewall, administrator access and backups among other things. It does not, however, have a SKU and does not cost anything. The scaling (and pricing) is managed by each database. Multiple databases can be connected to the same SQL server.

We will provision an SQL server that has your personal user as an administrator. We will also create an administrator username and secret that our web app can use. Finally, to simplify a little bit we'll open the database for traffic from everywhere on the internet.

:warning: Opening the database for traffic from everywhere is **bad**, and not something that should be done in production. Neither is using a developer directly as an administrator, nor using username/password to authenticate apps. The extra tasks at the end of the workshop describe how to set up virtual networks and proper identity management to protect the database.

1. To give your personal user access, we need to figure out what the `id` of your user is. Every user, group, service principal (representing an application identity) and other identity have a unique `id`, sometimes referred to as `objectId`.

    The Azure CLI can be used for many operations in Azure, and you can do almost every operation you can do with terraform or the Azure Portal using the CLI. It is logically grouped, and self documented. E.g., `az ad` works with Azure Active Directory (at the time of writing changing name to Azure Entra ID). Try running `az ad signed-in-user --help` to see the documentation.

    To view your user, run `az ad signed-in-user show`. This will output your user information in JSON format. We want the ID. It is also possible to parse the JSON using [JMESPath](https://jmespath.org/). To retrieve just the id, run `az ad signed-in-user show --query id --output tsv`. The JMESPath query is simple, just `id` to get the id from the JSON object. `--output tsv` tells `az` to format the output using tab-separated values, which is a handy way to remove quotes from quoted strings when scripting.

    We'll need the `id` in a later step.

2. To generate the administrator password, we'll generate a random string. Add the [Random provider](https://registry.terraform.io/providers/hashicorp/random/latest/docs) to the `required_providers` block in `terraform.tf`, followed by `terraform init` to initialize the provider.

    ```terraform
    random = {
      source = "hashicorp/random"
      version = "3.5.1"
    }
    ```

    Now, we can create a `random_password` resource to generate our password. Add the following code to `database.tf`:

    ```terraform
    resource "random_password" "sql_server_admin_password" {
      length  = 24
      special = false
    }
    ```

    This will create a random, 24-character password, which by default will contain uppercase, lowercase and special characters. The connection string cannot contain certain special characters without additional escaping, so we'll disable those. We can reference the password by using the `result` attribute: `random_password.sql_server_admin_password.result`. This password will be stored in the terraform state file, and will not be regenerated every time `terraform apply` is run.

3. Finally, let's create the SQL server. Change the `login_username` and `object_id` properties before running `terraform apply`:

    ```terraform
    resource "azurerm_mssql_server" "todo" {
      # Name, resource group and location
      name                = "sql-todo-${local.id}"
      resource_group_name = azurerm_resource_group.todo.name
      location            = azurerm_resource_group.todo.location

      # The SQL server version
      version = "12.0"

      # The (unsecure) administrator username and password
      administrator_login          = "unsecure-admin"
      administrator_login_password = random_password.sql_server_admin_password.result

      # The Azure AD (Entra ID) based administrator setup
      azuread_administrator {
        # Setting this to true will disable the administrator password-based login
        azuread_authentication_only = false
        # CHANGE THESE
        login_username              = "<any-user-name>"
        object_id                   = "<your-object-id-from-step-1>"
      }

      # Recommended security setting
      minimum_tls_version           = "1.2"
      # Is not enough to open the database to the public internet (despite the
      # name), but lets us configure firewall rules in a later step
      public_network_access_enabled = true
    }
    ```

4. Creating the database is rather simple, using the default settings:

    ```terraform
    resource "azurerm_mssql_database" "todo" {
      name      = "db-todo"
      server_id = azurerm_mssql_server.todo.id
      sku_name  = "Basic"
    }
    ```

5. Let's create a SQL server firewall rule to open for all external IP addresses:

    ```terraform
    resource "azurerm_mssql_firewall_rule" "todo" {
      name             = "All IPv4 addresses"
      server_id        = azurerm_mssql_server.todo.id
      start_ip_address = "0.0.0.0"
      end_ip_address   = "255.255.255.255"
    }
    ```

6. We can now define the `DATABASE_URL` environment variable for the web app, using app settings:

    ```terraform
    resource "azurerm_linux_web_app" "todo" {
      # ... code from before, add the app settings property
      app_settings = {
        DATABASE_URL = "sqlserver://${azurerm_mssql_server.todo.fully_qualified_domain_name}:1433;database=${azurerm_mssql_database.todo.name};user=${azurerm_mssql_server.todo.administrator_login};password=${random_password.sql_server_admin_password.result};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30"
      }
    }
    ```

    This will construct the required SQL server connection string. Note that we reference the SQL server domain name, the database name and the administrator login and password.

7. After running `terraform apply`, navigate to the web app in the Azure Portal, and find "Configuration" in the sidebar. Verify that the `DATABASE_URL` is registered as an application setting. Then go to the "Log stream" again to verify that the app started without errors. The container runs migrations on startup.

    Finally, go to the overview (the main page) of the web app. And go to the default domain listed there (`<something>.azurewebsites.net`). The root URL is not valid so you'll get "Cannot GET /" or similar. Try the `/users` route which should return an empty list as a JSON response.

## Frontend

We will use blob (object) storage to host our web site. An Azure Storage Account can host file shares, queues, blobs and tables. Blobs are organized into "Containers". Each container can contain many blobs. A blob can be a text file (HTML, javascript, txt), an image, a video or any other file. 

Storage accounts can replicate data across zones as regions. For backups, irreplaceable data, etc. replication across zones or regions should be considered. You can also choose between a standard and premium tier. The standard tier is usually sufficient for most use cases, but the premium performance tier can be considered if for applications with a lot of writes or latency sensitivity. Individual blobs also has access tiers, affecting the availability of the data, storage and access cost. All in all, the storage account pricing can be rather complicated, but in practice it is rather cheap and tweaking should only be necessary when the cost grows to high or performance is a problem. For hosting a static website behind a CDN, the cost is near zero.

When serving a static web site from a storage account, we will need to enable the "Static Website" feature and allow for public access. We will also use terraform to upload the files in the `frontend_dist/` folder.

We use a CDN in front of the storage account to provide a custom domain for the frontend. The CDN has multiple settings for doing redirects, caching and more that we (mostly) won't touch in this workshop, but are should be looked at for production use cases.

An Azure CDN has a profile, which represents the CDN and controls the pricing tier and groups CDN endpoints resources. Each endpoint represents content from a different source (origin), different caching rules, compression settings and custom domains.

1. Creating the storage account is straight forward. We need to enable static website and public access to blobs. Add this to a new file, `frontend.tf`:

    ```terraform
    resource "azurerm_storage_account" "todo_frontend" {
      name = "sttodo${local.id}"
      resource_group_name             = azurerm_resource_group.todo.name
      location                        = azurerm_resource_group.todo.location
      account_tier                    = "Standard"
      account_replication_type        = "LRS"
      allow_nested_items_to_be_public = true
      enable_https_traffic_only       = false # We'll change this in a later task
      min_tls_version                 = "TLS1_2"

      static_website {
        index_document = "index.html"
      }
    }
    ```

    Local redundant storage (LRS) is sufficient, since we're not afraid of data loss. We need to enable access to nested items (blobs) to serve data as a web page.

2. To upload files, terraform must track the files in the `frontend_dist/` directory. We also need some MIME type information that is not readily available, so we will create a *map* that we can use to look up the types later. We will create local helper variables to help us out:

    ```terraform
    locals {
      frontend_dir   = "${path.module}/../frontend_dist"
      frontend_files = fileset(local.frontend_dir, "**")

      mime_types = {
        ".js"   = "application/javascript"
        ".html" = "text/html"
      }
    }
    ```

    `path.module` is the path to the `infra/` directory. `fileset(directory, pattern)` returns a list of all files in `directory` matching `pattern`.

3. Each file we want to upload is represented by a `azurerm_storage_blob` resource. In order to create multiple resources, terraform provides a `for_each` meta-argument as a looping mechanism. We assign the `frontend_files` list to it, and can use `each.value` to refer to an element in the list.

    ```terraform
    resource "azurerm_storage_blob" "frontend_files" {
      for_each = local.frontend_files

      name                   = each.value
      storage_account_name   = azurerm_storage_account.todo_frontend.name
      storage_container_name = "$web"
      type                   = "Block"
      source                 = "${local.frontend_dir}/${each.value}"
      content_type           = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
      content_md5            = filemd5("${local.frontend_dir}/${each.value}")
    }
    ```

    The code snippet also performs a regex search to look up the correct content type. The `filemd5` calculates a hash of the file content, which is used to determined whether a file need to be re-uploaded. Without the hash, terraform would not be able to detect a file change (only new/deleted/renamed files).

    After `terraform apply` is done, navigate to the storage account in the Azure Portal, find "Containers" in the sidebar and select the "$web" container. Verify that you see your files there.

    Navigate to "Static website" in the sidebar, and find the "Primary endpoint". Copy it into a new tab in the browser, and verify that you get the "k6 demo todo frontend". Ignore the network error for now, that won't work before we've set up DNS properly.

4. We'll do the CDN configuration in one go:

    ```terraform
    resource "azurerm_cdn_profile" "todo_cdn_profile" {
      name                = "cdnp-todo-${local.id}"
      location            = azurerm_resource_group.todo.location
      resource_group_name = azurerm_resource_group.todo.name
      # Microsoft is fastest to get up and running for the workshop. Also cheapest, 
      # and we don't need special features provided by other alternatives
      sku = "Standard_Microsoft"
    }

    resource "azurerm_cdn_endpoint" "todo_cdn_endpoint" {
      name                = "cdne-todo-${local.id}"
      location            = azurerm_resource_group.todo.location
      resource_group_name = azurerm_resource_group.todo.name
      profile_name        = azurerm_cdn_profile.todo_cdn_profile.name

      # Configure the CDN endpoint to point to the storage container
      origin_host_header = azurerm_storage_account.todo_frontend.primary_web_host
      origin {
        name      = "origin"
        host_name = azurerm_storage_account.todo_frontend.primary_web_host
      }

      # Not required, and probably not what you want in production, but simplifies debugging configuration
      global_delivery_rule {
        cache_expiration_action {
          behavior = "BypassCache"
        }
      }
    }
    ```

5. Run `terraform apply`, and navigate to the CDN profile (of type "Front Door and CDN profile" in the Azure portal). Find your endpoint from the list, and use the "Endpoint hostname" on the endpoint overview page (`<something>.azureedge.net`) to verify that the CDN serves the frontend correctly. 

## DNS

The domain name we will use, `cloudlabs-azure.no`, is already configured in a DNS zone. You can find the DNS zone inside the `workshop-admin` resource group. We will configure two CNAME records. `api.<yourid42>.cloudlabs-azure.no` for the backend web app, and `<yourid42>.cloudlabs-azure.no` for the frontend CDN.

1. In order to define subdomain names, we need a reference to the DNS zone in our Terraform configuration. We will use a Terraform `data` block. A data block is very useful to refer to resources created externally, including resources created by other teams or common platform resources in an organization. Most resources in the `azurerm` provider have a corresponding data block.
    
    A DNS zone, can be uniquely identified by it's name and the parent resource group name. Add the following in `dns.tf`:
    
    ```terraform
    data "azurerm_dns_zone" "cloudlabs_azure_no" {
      name                = "cloudlabs-azure.no"
      resource_group_name = "workshop-admin"
    }
    ```

2. We can now create a CNAME record for the backend API:

    ```terraform
    resource "azurerm_dns_cname_record" "todo-api" {
      zone_name = data.azurerm_dns_zone.cloudlabs_azure_no.name
      resource_group_name = data.azurerm_dns_zone.cloudlabs_azure_no.resource_group_name

      ttl = 60
      name = "api.${local.id}"
      record = azurerm_linux_web_app.todo.default_hostname
    }
    ```

3. If you navigate to the new domain, `api.<yourid42>.cloudlabs-azure.no`, you will get an error. The web app must also know which custom domain it is served from:

    ```terraform
    resource "azurerm_app_service_custom_hostname_binding" "todo-api" {
      hostname = "${azurerm_dns_cname_record.todo-api.name}.${data.azurerm_dns_zone.cloudlabs_azure_no.name}"

      resource_group_name = azurerm_resource_group.todo.name
      app_service_name    = azurerm_linux_web_app.todo.name
    }
    ```

    *Note:* The order of provisioning is important. The custom hostname binding must be provisioned after the CNAME record. In this case, that is ensured by the implicit dependency on the record when declaring the hostname.

4. Using a CNAME record for a CDN works similarly: 

    ```terraform
    resource "azurerm_dns_cname_record" "todo_cdn" {
    #  
      zone_name = data.azurerm_dns_zone.cloudlabs_azure_no.name
      resource_group_name = data.azurerm_dns_zone.cloudlabs_azure_no.resource_group_name

      ttl = 60
      name = "${local.id}"
      record = azurerm_cdn_endpoint.todo_cdn_endpoint.fqdn
    }

    resource "azurerm_cdn_endpoint_custom_domain" "todo_frontend" {
      name            = local.id
      cdn_endpoint_id = azurerm_cdn_endpoint.todo_cdn_endpoint.id
      host_name       = trimsuffix(azurerm_dns_cname_record.todo_cdn.fqdn, ".")
    }
    ```

5. Now, navigate to `<yourid42>.cloudlabs-azure.no` and verify that you get the website and that the connection works!


## Extras

Unfinished, ask your workshop facilitator!

### Variables
### Vnet
### Web app healthcheck
### Scaling
### Slots
standard plan
### Budgets
### Get azure ad user id using Azure AD
### Tags
### Azure AD authentication only
### Keyvault with connection string
