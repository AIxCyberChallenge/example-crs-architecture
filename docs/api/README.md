# API

- Competitors will consume the API described by `competition-swagger-v0.1.yaml`
- Competitors will provide the API described by `crs-swagger-v0.1.yaml` 

NOTE: The JSON and YAML documents contain the same information and are generated from the same source.

## Viewing the UI

The swagger documents can be loaded into any swagger UI. One option is [https://editor.swagger.io](https://editor.swagger.io). It runs in the browser and is hosted by the main swagger developers. 

The provided Mock Competition API (scantron) will serve its swagger spec at `/swagger/index.html`. Competitors may find it useful to do the same for their CRS.

## Generating a Client or Server

It is possible to generate client or server code from the swagger documents. The documents are a best effort to provide a strongly typed schema but are not perfect. Use the generators at your own discretion.

One option is [https://swagger.io/tools/swagger-codegen/](https://swagger.io/tools/swagger-codegen/). This functionality is also built into the [https://editor.swagger.io](https://editor.swagger.io) website in the drop downs.