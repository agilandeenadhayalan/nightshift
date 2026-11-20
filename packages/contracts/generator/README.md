# Pinned OpenAPI Generator customizations

Generator: official OpenAPI Generator **7.26.0**, `dart`, native serialization. Templates under `templates/serialization/native/` and `templates/api_exception.mustache` are adapted from the Apache-2.0 licensed upstream release:

- [Release](https://github.com/OpenAPITools/openapi-generator/releases/tag/v7.26.0)
- [Upstream Dart templates](https://github.com/OpenAPITools/openapi-generator/tree/v7.26.0/modules/openapi-generator/src/main/resources/dart2)
- [Generator documentation](https://openapi-generator.tech/docs/generators/dart/)
- [Upstream license, retained locally](LICENSE.upstream)

Copyright OpenAPI Generator contributors. Local template changes are documented here; generated files must never be patched directly.

Customizations:

1. `native_class.mustache` replaces debug-only required-key assertions with runtime checks. Required nullability, list/object types, integer units, boolean types and date parsing reject malformed payloads. Model diagnostics contain only the model name and `[redacted]`, never property values. Lists reject invalid items instead of silently dropping them.
2. `native_enum*.mustache` rejects unknown non-null values and invalid list members. Upstream renders OpenAPI boolean constants as quoted strings; the boolean branch emits a constant boolean expression, preserving `true`/`false` JSON types without weakening the canonical schema.
3. `api_exception.mustache` exposes only the HTTP status in `toString`, excluding response bodies, credentials, nested exceptions and stack contents. The app facade maps structured server errors to its safe error model.
4. `pubspec.mustache` pins dependencies compatible with Flutter 3.27.4/Dart 3.6.2, including `http` 1.5.0 required for generator abortable requests. `README.mustache` points contributors to the source workflow.

These are supported Mustache overrides via the generator's `-t` option. Review them against upstream when updating the generator pin. The SDK is not a full JSON Schema validator; API validation still owns string formats, numerical/length bounds and authorization.

Pinned JAR SHA256: `1760050094997b9cc790cc1350be095f15da8c08a996b184d3eadc4ccda5e35e`.
Maven Central's published SHA1 (`b96b148fcf482808037f68fbad99cb4d7e65d40b`) matched the initial downloaded artifact; generation uses the stronger pinned SHA256. The JAR remains ignored and is never committed.
