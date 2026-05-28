terraform {
  required_version = ">= 1.15.5"

  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.12"
    }
  }


  cloud {
    organization = "wrtv23"

    # CLI workspace name maps 1:1 to a TFC workspace tagged 'rain-factory'.
    # Create one TFC workspace per org (name = "org1", "org2", ...) and tag
    # each with "rain-factory". `terraform workspace select <name>` switches
    # between them; `terraform.workspace` returns that name, which locals.tf
    # uses to load orgs/<name>/org.yaml.
    workspaces {
      tags = ["rain-factory"]
    }
  }
}
