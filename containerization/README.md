# OVH setup tips & tricks

## Default workspace

In order for OVH Cloud to be able to "take over" the deployment for it to be scalable, the base of the image must be a `workspace\` dir. More about this can be found [in this article](https://help.ovhcloud.com/csm/en-gb-public-cloud-ai-cli-deploy-app?id=kb_article_view&sysparm_article=KB0058346).

## Ownership givem to user 42420

You need to give OVH user ownership of /workspace and /models so it can read /models and write to /workspace/.ollama at runtime.

```bash
RUN chown -R 42420:42420 /workspace /models
```

### Accessing the endpoint

To access the endpoint, the deployment must be tagged and an access token generated [like on this guide](https://help.ovhcloud.com/csm/en-gb-public-cloud-ai-deploy-tokens?id=kb_article_view&sysparm_article=KB0047987).

We already have a token generated and if you need it, you can find it in this PRIVATE repo.
