---
name: New pipeline
description: Initiate the peer review process for a new pipeline
title: "[NEW PIPELINE]: "
labels: ["pipeline", "user contributed", "peer review needed"]
---

> [!IMPORTANT]
> To facilitate the peer review of the new pipeline, do not change the structure of this
> document. Only the parts in comments should be replaced.

## Contribution checklist
> Before submitting for review, please make sure that you meet these requirements:
- [ ] The pipeline meets the standards specified in the pipeline standards document
- [ ] The GitHub validations pass
- [ ] The license for the pipeline is specified and is open source
- [ ] The pipeline runs with the default values and has been tested with a range of other parameters
- [ ] The pipeline is accompanied by a tutorial 

## General information about the pipeline

**Title:** <!-- TITLE GOES HERE -->

> [!INFO]
> Short (1-2 sentence) description of the pipeline here

## Code information

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

## Diagram (recommended)

- [ ] Diagram of pipeline steps (e.g. [Mermaid][mermaid] diagram)

[mermaid]: https://github.blog/developer-skills/github/include-diagrams-markdown-files-mermaid/

## Suggested reviewers <!-- 2-3 -->
> Please include at least 3 potential pipeline reviewers to test the pipeline, review the code, and verify the methods.
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
