"
The REST Server for LiterateSmalltalk.
"
Class {
	#name : #LiterateServer,
	#superclass : #Object,
	#classVars : [
		'Server',
		'Started',
		'interactionModel',
		'transcriptLogStream'
	],
	#category : #LiterateSmalltalk
}

{ #category : #utilities }
LiterateServer class >> abortReq: req status: status message: message [

	req abort: {
			('status' -> status).
			('message' -> message) } asDictionary
]

{ #category : #'pharo api' }
LiterateServer class >> apiBrowseClass: req [

	| className class |
	className := req
		             at: #class
		             ifAbsent: [
		             self abortReq: req status: 'error' message: 'No class name is specified.' ].
	class := Smalltalk at: className asSymbol.
	Smalltalk tools browser openOnClass: class.
	self bringToFront.
	^ {
		  (#status -> #success).
		  (#message -> 'Opend in Pharo') } asDictionary
]

{ #category : #'pharo api' }
LiterateServer class >> apiBrowseImplementors: req [

	| methodName |
	methodName := req
		              at: #name
		              ifAbsent: [
		              self abortReq: req status: 'error' message: 'No name is specified.' ].
	SystemNavigation default browseAllImplementorsOf: methodName asSymbol.
	self bringToFront.
	^ {
		  (#status -> #success).
		  (#message -> 'Opend in Pharo') } asDictionary
]

{ #category : #'query api' }
LiterateServer class >> apiCatMethods: req [

	| className cat side class methods allMethods |
	className := req at: #class.
	cat := req at: #cat.
	side := req at: #side.
	class := Smalltalk at: className asSymbol.
	side = #class ifTrue: [ class := class class ].

	allMethods := class methodDictionary ifNil: [ #(  ) ] ifNotNil: [ :x | x associations ].

	methods := cat = '*'
		           ifTrue: [ allMethods ]
		           ifFalse: [ allMethods select: [ :e | e value category = cat ] ].
	^ {
		  (#status -> #success).
		  (#methods -> (methods collect: [ :each | each key asString ]) asSortedCollection) }
		  asDictionary
]

{ #category : #'query api' }
LiterateServer class >> apiClassCats: req [

	| className class cats result |
	className := req at: #class.
	result := Dictionary new.
	class := Smalltalk at: className asSymbol.
	cats := Set new.
	class methodDictionary ifNotNil: [ :d | d valuesDo: [ :each | cats add: each category ] ].

	result at: #instance put: cats.

	class := class class.
	cats := Set new.
	class methodDictionary ifNotNil: [ :d | d valuesDo: [ :each | cats add: each category ] ].
	result at: #class put: cats.
	^ {
		  (#status -> #success).
		  (#result -> result) } asDictionary
]

{ #category : #'query api' }
LiterateServer class >> apiClassDef: req [

	| className class instanceSide classSide result |
	className := req at: #class.
	class := Smalltalk at: className asSymbol.
	instanceSide := Dictionary new.
	instanceSide at: #class put: className.
	instanceSide at: #superclass put: class superclass printString.
	instanceSide at: #instvars put: (self asStringArray: class instVarNames).
	instanceSide at: #classvars put: (self asStringArray: class classVarNames).
	instanceSide at: #poolvars put: (self asStringArray: class sharedPools).
	instanceSide at: #package put: class category.
	instanceSide at: #comment put: class comment.

	class := class class.
	classSide := Dictionary new.
	classSide at: #class put: className.
	classSide at: #superclass put: class superclass printString.
	classSide at: #instvars put: (self asStringArray: class instVarNames).
	classSide at: #classvars put: (self asStringArray: class classVarNames).
	classSide at: #poolvars put: (self asStringArray: class sharedPools).
	result := Dictionary new.
	result at: #instance put: instanceSide.
	result at: #class put: classSide.
	^ {
		  (#status -> #success).
		  (#result -> result) } asDictionary
]

{ #category : #'query api' }
LiterateServer class >> apiClasses: req [

	| namespace resultList |
	namespace := req at: #namespace.
	resultList := Smalltalk globals allClasses select: [ :each |
		              each category asString = namespace ].
	^ {
		  (#status -> #success).
		  #classes -> (resultList collect: [ :each | each name asString ])  } asDictionary
]

{ #category : #'compiling api' }
LiterateServer class >> apiCompileClass: req [

	| receiver evaluationContext status |
	status := #success.

	receiver := interactionModel doItReceiver.
	evaluationContext := interactionModel doItContext.

	[
	receiver class compiler
		source: (req at: #code);
		context: evaluationContext;
		receiver: receiver;
		requestor: nil;
		"As it is a remote request, we allow compiler handle messages such as exceptions"
			evaluate ]
		on: Error
		do: [ :e |
			^ {
				  (#status -> #failed).
				  (#message -> e asString) } asDictionary ].
	^ { (#status -> status) } asDictionary
]

{ #category : #'compiling api' }
LiterateServer class >> apiCompileMethod: req [

	| className cat source side class status selector critiques message |
	className := req at: #class.
	cat := req at: #category.
	source := req at: #source.
	side := req at: #side.
	class := Smalltalk at: className asSymbol.
	side = #class ifTrue: [ class := class class ].

	status := #success.
	critiques := ''.
	selector := ''.
	message := ''.
	[
	selector := class compile: source classified: cat.
	critiques := (class >> selector) critiques collect: [ :critique |
		             | anchor first last |
		             anchor := critique sourceAnchor interval.
		             first := anchor ifNotNil: [ anchor first ].
		             last := anchor ifNotNil: [ anchor last ].
		             {
			             (#message -> critique asString).
			             (#first -> first).
			             (#last -> last) } asDictionary ] ]
		on: SyntaxErrorNotification , OCAbortCompilation , OCSemanticError , OCSemanticWarning
			, ReparseAfterSourceEditing
		do: [ :ex |
			message := ex asString.
			status := ex className ].
	^ {
		  (#status -> status).
		  (#message -> message).
		  (#selector -> selector).
		  (#critiques -> critiques) } asDictionary
]

{ #category : #'compiling api' }
LiterateServer class >> apiCompletionMethod: req [

	| className source class context entities |
	className := req at: #class.
	source := req at: #source.
	class := Smalltalk at:
		         (className ifEmpty: [ #GTPlayground ] ifNotEmpty: [ className asSymbol ]).
	context := CompletionContext
		           engine: CompletionEngine new
		           class: class
		           source: source
		           position: source size.
	entities := context entries collect: [ :each | each contents ].
	^ {
		  (#status -> #success).
		  (#entities -> entities) } asDictionary
]

{ #category : #'compiling api' }
LiterateServer class >> apiEvalBindings: req [

	self bringToFront.
	GTInspector inspect: interactionModel bindings.
	^ {
		  (#status -> #success).
		  (#message -> 'Inspector has been opened.') } asDictionary
]

{ #category : #'compiling api' }
LiterateServer class >> apiEvalCode: req [

	| code openInspector status result receiver evaluationContext |
	code := req at: #code.
	openInspector := (req at: #inspector ifAbsent: 'false') = 'true'.
	status := #success.
	receiver := interactionModel doItReceiver.
	evaluationContext := interactionModel doItContext.
	result := receiver class compiler
		          source: code;
		          context: evaluationContext;
		          receiver: receiver;
		          requestor: nil; "As it is a remote request, we allow compiler handle messages such as exceptions"
		          failBlock: [ ^ nil ];
		          evaluate.

	openInspector ifTrue: [
		self bringToFront.
		GTInspector inspect: result ].
	^ {
		  (#message -> result asString).
		  (#status -> status) } asDictionary
]

{ #category : #'compiling api' }
LiterateServer class >> apiFormatCode: req [

	| source type tree errBlock |
	source := req at: #source.
	type := req at: #type.
	errBlock := [ :msg :pos |
	            ^ {
		              (#status -> #failed).
		              (#msg -> msg).
		              (#pos -> pos) } asDictionary ].
	tree := type = 'method'
		        ifTrue: [ RBParser parseMethod: source onError: errBlock ]
		        ifFalse: [ RBParser parseExpression: source onError: errBlock ].
	^ {
		  (#status -> #success).
		  (#source -> tree formattedCode) } asDictionary
]

{ #category : #'query api' }
LiterateServer class >> apiMethodSource: req [

	| className methodName side class method |
	className := req at: #class.
	methodName := req at: #name.
	side := req at: #side.
	class := Smalltalk at: className asSymbol.
	class := side = #class
		         ifTrue: [ class class ]
		         ifFalse: [ class ].
	method := class methodDictionary at: methodName asSymbol.
	^ {
		  (#status -> #success).
		  (#source -> method sourceCode) } asDictionary
]

{ #category : #'query api' }
LiterateServer class >> apiNamespaces: req [

	| names |
	names := (Smalltalk globals allClasses collect: [ :each | each category asString ]) asSet
		         asSortedCollection.
	^ {
		  (#status -> #success).
		  (#namespaces -> names) } asDictionary
]

{ #category : #'query api' }
LiterateServer class >> apiPackageExtensions: req [

	| packageName package methods |
	packageName := req at: #package.
	package := RPackageOrganizer default
		           packageNamed: packageName asSymbol
		           ifAbsent: RPackage new.
	methods := package extensionMethods collect: [ :each |
		           | class side |
		           class := each methodClass.
		           side := #instance.
		           (class isKindOf: Metaclass) ifTrue: [
			           side := #class.
			           class := class instanceSide ].
		           {
			           (#name -> each name).
			           (#selector -> each selector).
			           (#category -> each category).
			           (#side -> side).
			           (#code -> each sourceCode).
			           (#class -> class asString) } asDictionary ].
	^ {
		  (#status -> #success).
		  (#methods -> methods) } asDictionary
]

{ #category : #'query api' }
LiterateServer class >> apiPackageTags: req [

	| packageName package tags |
	packageName := req at: #package.
	package := RPackageOrganizer default
		           packageNamed: packageName asSymbol
		           ifAbsent: RPackage new.
	tags := (package classTags collect: [ :tag |
		         {
			         (#name -> tag name asString).
			         (#classes -> (tag orderedClasses collect: [ :each | each asString ])) }
			         asDictionary ]) sorted: [ :item | item at: #name ] ascending.
	^ {
		  (#status -> #success).
		  (#tags -> tags) } asDictionary
]

{ #category : #'query api' }
LiterateServer class >> apiPackages: req [

	^ {
		  (#status -> #success).
		  (#packages -> RPackageOrganizer default packageNames) } asDictionary
]

{ #category : #'compiling api' }
LiterateServer class >> apiRemoveClass: req [

	| className class |
	className := req at: #class.
	class := Smalltalk at: className asSymbol ifAbsent: nil.
	class ifNil: [
		^ {
			  (#status -> #failed).
			  (#message -> 'class Not Found') } asDictionary ].
	class removeFromSystem.
	^ {
		  (#status -> #success).
		  (#message -> '') } asDictionary
]

{ #category : #'compiling api' }
LiterateServer class >> apiRemoveSelector: req [

	| className methodName side class status message |
	className := req at: #class.
	methodName := req at: #name.
	side := req at: #side.
	class := Smalltalk at: className asSymbol.
	class := side = #class
		         ifTrue: [ class class ]
		         ifFalse: [ class ].
	status := #success.
	message := ''.
	[ class removeSelector: methodName asSymbol ]
		on: Exception
		do: [ :ex |
			message := ex asString.
			status := ex className ].
	^ {
		  (#status -> status).
		  (#message -> message) } asDictionary
]

{ #category : #utilities }
LiterateServer class >> asStringArray: items [

	^ (items collect: [ :each | each asString ]) asArray
]

{ #category : #utilities }
LiterateServer class >> bringToFront [

	"a way to bring pharo window to front"
	LibC uniqueInstance system: 'xdotool search --name ''Pharo'' windowactivate'
]

{ #category : #management }
LiterateServer class >> dispatch: req [

	| apiName methodName |
	apiName := req
		           at: #api
		           ifAbsent: [ self abortReq: req status: 'fatal' message: 'No api specified.' ].
	methodName := ('api' , apiName , ':') asSymbol.
	(self class canUnderstand: methodName) ifFalse: [
		self abortReq: req status: 'fatal' message: 'No implementation for this api' ].
	^ self perform: methodName with: req
]

{ #category : #utilities }
LiterateServer class >> elementsString: items [

	^ items inject: '' into: [ :acc :each | acc , each asString , ' ' ]
]

{ #category : #utilities }
LiterateServer class >> releaseIcebergPackage: icebergPackage [

	| iceRepository location srcDirectory |
	iceRepository := IceRepository registeredRepositoryIncludingPackage:
		                 (RPackageOrganizer default packageNamed: icebergPackage).
	location := iceRepository location.
	srcDirectory := iceRepository project properties at: 'srcDirectory' ifAbsent: ''.
	srcDirectory ifNotEmpty: [ location := location / srcDirectory ].
	iceRepository workingCopy packages do: [ :package |
		| packageName |
		packageName := package package.
		(RPackageOrganizer default packageNamed: packageName asSymbol) classTags do: [ :tag |
			tag orderedClasses do: [ :class |
				| file |
				file := location / ('{1}/{2}.class.st' format: {
						         packageName.
						         class asString }).
				file exists ifTrue: [ file delete ].
				file
					writeStreamDo: [ :s | TonelWriter exportClass: class on: s ];
					yourself ] ] ]
]

{ #category : #accessing }
LiterateServer class >> server [
	"returns teapot instance"
	^ Server
]

{ #category : #accessing }
LiterateServer class >> server: server [
	"sets teapot for class"
	Server := server.
]

{ #category : #management }
LiterateServer class >> start [

	"Start the webserver"

	| teapot |
	"extra check so that we don't close a Pool which wasn't open"
	Started ifNotNil: [ Server stop ].
	Transcript addDependent: self.
	teapot := Teapot configure: {
			          (#defaultOutput -> #json).
			          (#port -> 9092).
			          (#debugMode -> true).
			          (#bindAddress -> #[ 127 0 0 1 ]) }.
	teapot server logLevel: 1.
	self server: teapot.
	teapot
		addRouteMethod: TeaMethodMatcher any
		pattern: '/api/<api>/*'
		action: [ :req | self dispatch: req ];
		output: #json;
		exception: Exception -> [ :ex :req |
				(ex isKindOf: Notification) ifFalse: [
						Transcript
							show: 'bring pharo to front because of ';
							show: ex asString;
							cr.
						self bringToFront.
						ex pass ].
				ZnResponse serverError: (NeoJSONWriter toString: {
							 (#status -> #fatal).
							 (#message -> ex asString) } asDictionary) ];
		start.
	interactionModel := StPlaygroundInteractionModel new owner: StPlaygroundPagePresenter new.
	Started := true
]

{ #category : #updating }
LiterateServer class >> update: aChange [

	aChange = #appendEntry ifFalse: [ ^ self ].
	transcriptLogStream ifNotNil: [
		transcriptLogStream closed ifTrue: [ transcriptLogStream := nil ] ].
	transcriptLogStream ifNil: [
		transcriptLogStream := ((OSEnvironment current at: 'HOME')
		                        , '/.cache/literate-smalltalk/transcript.log') asFileReference
			                       writeStream.
		transcriptLogStream setToEnd ].
	transcriptLogStream print: Transcript contents.
	transcriptLogStream flush
]
