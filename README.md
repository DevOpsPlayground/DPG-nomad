# scratchpad

## link

[http://funny-panda.devopsplayground.org:8000/?folder=/home/coder]

## Flow

Try plan coder - talk about allocations

`nomad job plan coder.hcl`

Install docker

`nomad job run docker.hcl`

see in UI that it now works

annoying need to set random port

set a static port to ` static = 8080 `

---- Dont think this is a good idea any more, maybe deploy with terraform insted. or one vault node to show vars?

run vault see client error. Edit server to also run client

```bash
cat >> /etc/nomad.d/config.hcl << EOF
client {
    enabled = true
}
EOF
systemctl restart nomad
```

now have 2 clients

deploy vault to show variable and distinct hosts though no auto join set up, would nginx be better?

deploy nginx via terraform

add service to nginx redeploy

