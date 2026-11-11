# Documentation guide

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](README.vi.md)

Start here for the architecture, setup, translation lifecycle, provider contracts, security, operations and verified scope of Rails 8 Multilingual AI Translation.

## Guides

| Topic | Document |
|---|---|
| Architecture and data model | [Architecture](architecture.md) |
| Local and production configuration | [Configuration](configuration.md) |
| Translation lifecycle and comparisons | [Translation workflow](translation-workflow.md) |
| Provider API behavior | [API integration](api.md) |
| Authentication and threat boundaries | [Security](security.md) |
| Validation and CI | [Testing](testing.md) |
| Worker and database operations | [Operations](operations.md) |
| Known constraints | [Limitations](limitations.md) |
| Common failures | [Troubleshooting](troubleshooting.md) |
| Runtime evidence and outstanding checks | [Implementation status](IMPLEMENTATION_STATUS.md) |
| UI localization and session policy | [Security and localization](SECURITY_AND_LOCALIZATION.md) |

## Scope

This repository contains the Rails application, not the model weights or inference infrastructure. The independently deployed [translation inference service](https://github.com/dangkhoa2016/Multilingual-Translation-AI-Inference) has its own deployment and API lifecycle. Rails CI uses local tests and mocks, not paid GPU calls.

Return to [repository README](../README.md).
