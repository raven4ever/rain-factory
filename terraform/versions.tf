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
  }
}
