@cola = cola = () ->
	return cola["_rootFunc"]?.apply(cola, arguments)

#IMPORT_BEGIN
module?.exports = cola
#IMPORT_END

cola.util = {}

cola.constants = {
	VARIABLE_NAME_REGEXP: /^[_a-zA-Z][_a-zA-Z0-9]*$/g

	VIEW_CLASS: "c-view"
	VIEW_PORT_CLASS: "c-viewport"
	IGNORE_DIRECTIVE: "c-ignore"

	COLLECTION_CURRENT_CLASS: "current"

	DEFAULT_PATH: "$root"

	DOM_USER_DATA_KEY: "_d"
	DOM_BINDING_KEY: "_binding"
	DOM_INITIALIZER_KEY: "_initialize"
	REPEAT_TEMPLATE_KEY: "_template"
	REPEAT_TAIL_KEY: "_tail"
	DOM_ELEMENT_KEY: "_element"

	NOT_WHITE_REG: /\S+/g
	CLASS_REG: /[\t\r\n\f]/g
	WIDGET_DIMENSION_UNIT: "px"

	MESSAGE_REFRESH: 0
	MESSAGE_DATA_CHANGE: 1

	MESSAGE_CURRENT_CHANGE: 10
	MESSAGE_EDITING_STATE_CHANGE: 11
	MESSAGE_VALIDATION_STATE_CHANGE: 15

	MESSAGE_INSERT: 20
	MESSAGE_REMOVE: 21

	MESSAGE_LOADING_START: 30
	MESSAGE_LOADING_END: 31
}
