---
name: New pipeline
description: Initiate the peer review process for a new pipeline
title: "[NEW PIPELINE]: "
labels: ["pipeline", "user contributed", "peer review needed"]
---

> [!IMPORTANT]
> To facilitate the peer review of the new pipeline, do not change the structure of this
> document. Only the parts in comments should be replaced.

## General information about the pipeline

**Title:** <!-- TITLE GOES HERE -->

| Author | Affiliation | GitHub ID | ORCID | [CRediT Role][role] |
|-------|-----|----|----|---|
| | | | | |

[role]: https://credit.niso.org/

> [!INFO]
> Abstract of the pipeline goes here

## Code information

**GitHub repo:** <!-- REPO URL -->

**LICENSE:** <!-- LICENSE NAME HERE -->

> [!NOTE]
> The pipeline license **must** be FOSS (free and open source software), **should** not require the same license for
> derived products, and **must** be inclided as either `LICENSE` or `LICENSE.md` in the folder of the
> pipeline. You can delete this note when this is completed.

**Languages used:**

- [ ] R (version)
- [ ] Julia (version)
- [ ] Python (version)
- [ ] other

> [!INFO]
> For each *other* language, copy this quote block and list the language, version, and other
> relevant information

**Dependencies manager:** <!-- List all packages and their versions here (note: list versions even if the versions are not specified in the Conda dependencies for future versioning) -->

> [!INFO]
> Pipelines **must** be accompanied a list of their dependencies, including information about
> which versions are usable. You can delete this note when done.

## Additional information

**Testing:** <!-- free-form text to explain the testing/CI of the pipeline -->

[!INFO]
> Please include an explanation of how the pipeline should be tested. 
> This should include guidelines on how to parameterize the pipeline.

## Optional (recommended)

- [ ] [Mermaid][mermaid] diagram

[mermaid]: https://github.blog/developer-skills/github/include-diagrams-markdown-files-mermaid/

## Suggested reviewers <!-- 2-3 -->
- Name 1 (email)
- Name 2 (email)
- Name 3 (email)

## Review information

| Date | Step | Comments | User |
|----|----|----|----|
| <!-- TODAY YYYY-MM-DD --> | Submission | | <!-- YOUR GITHUB ID --> |
| | Initial check | | |
| | Review started | | |
| | Reviewer 1 invited | | |
| | Reviewer 2 invited | | |
