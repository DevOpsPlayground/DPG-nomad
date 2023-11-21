# README

## link

< link to DPG lab site >

## 1)

The first thing we are going to do with nomad is try and set up coder which is the web based IDE.

If you create a file called `coder.hcl` and add the following code:

```hcl
job "coder" {
  datacenters = ["*"]
  
  group "coder"{
    count = 1
    network {
      mode = "host"
      port "coder" {
        to = 8080
      }
    }

    task "coder" {
      driver = "docker"
      meta {
        service = "coder"
      }
      config {
        image = "codercom/code-server:latest"
        ports = ["coder"]
        args = ["--auth","none"]
        volumes = [
          # Use absolute paths to mount arbitrary paths on the host
          "local/repo:/home/coder/project",
        ]
      }
      artifact {
        source      = "https://github.com/BLINKBYTE/nomad/archive/refs/heads/main.zip"
        destination = "local/repo"
      }
    } 
  }
}

```

Before we deploy the code it is worth looking though it an talking about what parts of it do.

`job` is the block around everything, when you are deploying though nomad you are deploying jobs.
`datacenters = ["*"]` lets you limit the datacenter you are deploying in to, this is good if you only have access to a part of the cluster `*` means it will just deploy to where ever has space.
`group` with in a job there are groups, this group up setting and tasks. But one job can have many groups.
`network` this sets up the networking. As we want access to this from the web we are using `host` mode so the service will have a port on the client.
`task` is the bit that does the deployment, in this case the task deploys a docker image (which is the `driver` type)
`config` in this context is the docker config that will be passed through
`artifact` is a way of downloading (and unzipping if required) any files the the task requires.

now we know that it is time to deploy run. we can run
`nomad job plan coder.hcl`
to check what it is trying to do. If we look at the plan it looks like there is no client that meets the requirment for the allocation.

This is because the client doesnt have docker installed. You can see this if you go in to the client info on the web UI. To fix this lets use nomad to deploy docker on the client.

## 2)

lets make a file called `docker.hcl` and pasted in:

```hcl
job "docker" {
  type = "sysbatch"
  datacenters = ["*"]

  task "docker" {
    driver = "raw_exec"

    config {
        command = "sh"
        args =  ["local/setup.sh"]
    }
    template {
      destination = "local/setup.sh"
      data = <<EOH
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
EOH
    }
  }
}
```

While this file looks messy most of it is the `template` block which is similar to the `artifact` block from before but lets us pass in text and use varaible (which we will see later)
There are 2 other feilds we havent seen that do some intresting stuff
`type = "sysbatch"` this tells nomad this is used to set up the clients, so run it once then be happy that is has finished.
`driver = "raw_exec"` last time we used the docker driver to run in a segrigated docker image. This driver type lets you run commands stright on the server. It probily isnt a good idea to let users do this in production. But it shows off how nomad can be used to set up nomad.

To run this use the command:
`nomad job run docker.hcl`
once that has succeded, docker should be installed and set up correctly on the client.

We can now run the coder example successfully

## 3)

to deploy the coder example run:
`nomad job run coder.hcl`

This should have deployed coder with a random port on the server, you can see it by looking at the allocation on the nomad UI.

This is a bit annoying to have to do and it would be good if we could set the IP. Luckly there is an option to set the ip to be static. In the `coder.hcl` file replace the network block with:

```hcl
network {
  mode = "host"
  port "coder" {
    to = 8080
    static =8080
  }
}
```

Now redeploy with:
`nomad job run coder.hcl`
This will create a new version of the same deployment. And you should now be able to go to the `<clients ip>:8080` and see coder.

## 4)

We are now going to be a slightly more complicated examble, lets deploy Hashicorp Vault on to it. Though we are going to be deploying 2 nodes, we arnt going to be dealing with auto join or unsealing them.

Lets create a file called `vault.hcl` and pasted in the following:

```hcl
job "vault" {
  datacenters = ["*"]
  
  group "vault"{
    constraint {
      operator  = "distinct_hosts"
      value     = "true"
    }
    count = 2
    network {
      port "vault_api" {
        static = 8200
        to=  8200
      }
      port "vault_cluster" {}
    }

    task "vault" {
      driver = "exec"
      meta {
        service = "vault"
      }
      config {
        command = "local/vault"
        args    = ["server", "-config=local/config.hcl"]
      }
      artifact {
        source      = "https://releases.hashicorp.com/vault/1.14.0/vault_1.14.0_linux_amd64.zip"
        destination = "local"
      }
      template {
        destination = "local/config.hcl"
        data = <<EOH
api_addr = "https://{{env  "attr.unique.platform.aws.public-ipv4"}}:{{env "NOMAD_PORT_vault_api"}}"
cluster_addr = "https://{{env "attr.unique.platform.aws.public-ipv4"}}:{{env "NOMAD_PORT_vault_cluster"}}"
ui = true
storage "raft" {
  path = "local"
  node_id = "{{ env "node.unique.id" }}"
}

listener "tcp" {
  address = "0.0.0.0:{{env  "NOMAD_HOST_PORT_vault_api"}}"
  tls_disable = true
}
EOH
      }
    } 
  }
}

```

This code does quite a bit, but most of it we have see before. The stuff we haven't seen before is:
`constraint` we are using this to only deploy 1 node per client, as having 2 nodes on the same client wouldn't help with High Avalibility
`{{env ""}}` This is how we pull in variables from nomad on to the template files.
`driver = "exec"` lets you run executable files on the client in a segrigated way, so we dont have to deal with putting apps in docker when they dont have any docker support.

We can now deploy this with:
`nomad job run vault.hcl`

If we look at the deployment, it looks like it was able to start one allocaiton but it cant find a client that matchs the conditions to start another. This is becase we only have 1 client currently started, but have the `constraint` they all have to be on diffrent clients.

To fix this we are going to edit the server to also be a client. This is good for small set ups but in prod you would want to keep the server client split.

## 5)

Open up wetty (The web terminal) and run:

```bash
cat >> /etc/nomad.d/config.hcl << EOF
client {
    enabled = true
}
EOF
systemctl restart nomad
```

This will append the config file with a client block, and then restart the server. If you go to the client part of the UI you should now see 2 servers, both with vault deployed in them

## 6)

The next step we are going to deploy something in nomad though terraform. As an example of this we are going to deploy nginx.

To start with this we will create a file called `nginx.hcl` with includes:

```hcl
job "nginx" {
  datacenters = ["*"]

  group "nginx"{
    count = 1
    network {
      mode = "host"
      port "web" {
        to = 80
      }
    }
    task "nginx" {
      driver = "docker"
      meta {
        service = "nginx"
      }
      config {
        image = "nginx:latest"
        ports = ["web"]
      }
    } 
  }
}

```

We have seen all these parts before we are just deploying a nginx docker container.
To get it deployed with terraform we will create a file called `nginx.tf` with the following context:

```hcl
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

```

This gives the infomation that terraform needs and then uses the resource block to deploy the file.
You can run it with `terraform init; terraform apply` which will setup terrform and apply the code.
Then in the UI you can see the port that it is deployed on nomad.

## 7)

One last peice of cool functionality nomad has that we can mess with is health checks.
We can enable this by using a service block. In the `group block` of the nginx job add:

```hcl
service {
  provider = "nomad"
  port = "web"
  check {
    type     = "http"
    name     = "app_health"
    path     = "/"
    interval = "20s"
    timeout  = "5s"

    check_restart {
      limit = 3
      grace = "90s"
      ignore_warnings = false
    }
  }
}
```

Then rerun `terraform apply`. You will see the nice plan saying what is changing, then once it is deployed we can do in to the UI and under the task see that it is all green and healthy.
