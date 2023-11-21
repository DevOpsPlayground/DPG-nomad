terraform {
  required_providers {
    nomad = {
      source = "hashicorp/nomad"
      version = "2.0.0"
    }
  }
}

provider "nomad" {
  address = "http://127.0.0.1:4646/"
}

resource "nomad_job" "app" {
  jobspec = file("${path.module}/nginx.hcl")
}