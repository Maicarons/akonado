@tool
extends Resource
class_name KonadoData

## Shared base type for editable Konado data resources.
##
## Domain resources inherit this type so tooling and public APIs can identify
## Konado-owned data without depending on a specific audio, stage or variable
## implementation. Executable KonadoScript documents use [KonadoShot] instead.
