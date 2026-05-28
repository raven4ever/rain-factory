# Rain Factory

## Scope

This repo is a GitOps control plane for MongoDB Atlas at enterprise scale. It provisions Atlas organizations, projects, clusters, users, network access, and federation role mappings through YAML configuration backed by Terraform modules.
The product is the developer experience.
This is a POC/POT. The goal is to validate the end-to-end design with one pilot team, not to ship a fully polished platform.

## Code Style

### Terraform

After any Terraform code modification, run `terraform fmt`.
Prefer to define IAM policies as `data` objects rather than `jsonencode` function.

### YAML

Use 2-space indent. Lowercase keys with kebab-case only for AD group names; everything else camelCase.
Optional sections are omitted, not empty-listed. Don't write managementUsers: []; just leave it out.
String fields that look like numbers (account IDs) are quoted: awsAccount: "123456789012".

### Markdown

Write a paragraph as a single line to ease PR reviews.

## Documentation

Any documentation produced for this project will be placed in the `docs` folder.

## Way of Working

Always use multiple agents to plan, orchestrate, implement and test features.
Always use the caveman skills to communicate more efficiently and to save tokens.
When in doubt, ask the user for clarification.
Check the decision log before re-litigating a design call.
When planning, break the implementation in phases so that at the end of each phase the application is fully able to showcase the features developed by that moment.
