terraform {
  required_version = ">= 1.15.5"

  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.12"
    }
  }


  cloud {
    organization = "raven4ever"

    # CLI workspace name maps 1:1 to a TFC workspace tagged app=rain-factory
    # inside Project 'rain-factory'. Create one TFC workspace per org
    # (name = "org1", "org2", ...), add tag `app = rain-factory` to each,
    # and place them in the rain-factory Project. `terraform workspace select
    # <name>` switches between them; `terraform.workspace` returns that name,
    # which locals.tf uses to load orgs/<name>/org.yaml.
    workspaces {
      project = "rain-factory"
      tags = {
        app = "rain-factory"
      }
    }
  }
}
