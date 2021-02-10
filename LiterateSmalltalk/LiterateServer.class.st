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
LiterateServer class >> asStringArray: items [

	^ (items collect: [ :each | each asString ]) asArray
]

{ #category : #utilities }
LiterateServer class >> bringToFront [

	"a way to bring pharo window to front"

	Display toggleFullscreen.
	Display toggleFullscreen.
]

{ #category : #accessing }
LiterateServer class >> catMethods: className category: cat side: side [

	| class methods allMethods |
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

{ #category : #accessing }
LiterateServer class >> classCats: className [

	| class cats result |
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

{ #category : #accessing }
LiterateServer class >> classDef: className [

	| class instanceSide classSide result |
	class := Smalltalk at: className asSymbol.
	instanceSide := Dictionary new.
	instanceSide at: #class put: className.
	instanceSide at: #superclass put: class superclass printString.
	instanceSide
		at: #instvars
		put: (self asStringArray: class instVarNames).
	instanceSide
		at: #classvars
		put: (self asStringArray: class classVarNames).
	instanceSide
		at: #poolvars
		put: (self asStringArray: class sharedPools).
	instanceSide at: #package put: class category.
	instanceSide at: #comment put: class comment.

	class := class class.
	classSide := Dictionary new.
	classSide at: #class put: className.
	classSide at: #superclass put: class superclass printString.
	classSide at: #instvars put: (self asStringArray: class instVarNames).
	classSide
		at: #classvars
		put: (self asStringArray: class classVarNames).
	classSide at: #poolvars put: (self asStringArray: class sharedPools).
	result := Dictionary new.
	result at: #instance put: instanceSide.
	result at: #class put: classSide.
	^ {
		  (#status -> #success).
		  (#result -> result) } asDictionary
]

{ #category : #accessing }
LiterateServer class >> classes: namespace [

	| resultList |
	resultList := Smalltalk globals allClasses select: [ :each |
		              each category asString = namespace ].
	^ {
		  (#status -> #success).
		  #classes -> (resultList collect: [ :each | each name asString ])  } asDictionary
]

{ #category : #compile }
LiterateServer class >> compileClass: instDef class: classDef [

	| parent class status instvars classvars |
	status := #success.
	instvars := ''.
	(instDef at: #instvars) ifNotNil: [
		instvars := self elementsString: (instDef at: #instvars) ].
	classvars := ''.
	(instDef at: #classvars) ifNotNil: [
		classvars := self elementsString: (instDef at: #classvars) ].

	"Looks a bit kludgy, but currently I dont know how to make it better. TODO: refactor"
	parent := Smalltalk at: (instDef at: #super) asSymbol.
	[
	class := parent
		         subclass: (instDef at: #name) asSymbol
		         instanceVariableNames: instvars
		         classVariableNames: classvars
		         poolDictionaries: ''
		         category: (instDef at: #package) ]
		on: Error
		do: [ :e |
			^ {
				  (#status -> #instFailed).
				  (#message -> e asString) } asDictionary ].
	class := Smalltalk at: (instDef at: #name) asSymbol ifAbsent: [ nil ].
	class comment: (instDef at: #comment).
	"On Pharo, there were a strange exception when using the safe form."
	instvars := ''.
	(classDef at: #instvars) ifNotNil: [
		instvars := self elementsString: (classDef at: #instvars) ].
	class class instanceVariableNames: instvars.
	^ { (#status -> status) } asDictionary
]

{ #category : #compile }
LiterateServer class >> compileMethod: className category: cat source: source side: side [

	| class status selector critiques message |
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

{ #category : #compile }
LiterateServer class >> completion: className source: source [

	| class context entities |
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

{ #category : #utilities }
LiterateServer class >> elementsString: items [

	^ items inject: '' into: [ :acc :each | acc , each asString , ' ' ]
]

{ #category : #compile }
LiterateServer class >> evalBindings [

	self bringToFront.
	GTInspector inspect: interactionModel bindings.
	^ {
		  (#status -> #success).
		  (#message -> 'Inspector has been opened.') } asDictionary
]

{ #category : #compile }
LiterateServer class >> evalCode: code openInspector: openInspector [

	| status result receiver evaluationContext |
	status := #success.
	receiver := interactionModel doItReceiver.
	evaluationContext := interactionModel doItContext.
	result := receiver class compiler
		          source: code;
		          context: evaluationContext;
		          receiver: receiver;
		          requestor: interactionModel;
		          failBlock: [ ^ nil ];
		          evaluate.

	openInspector ifTrue: [
		self bringToFront.
		GTInspector inspect: result ].
	^ {
		  (#message -> result asString).
		  (#status -> status) } asDictionary
]

{ #category : #compile }
LiterateServer class >> formatCode: source type: type [

	| tree errBlock |
	errBlock := [ :msg :pos |
	            ^ {
		              (#status -> #failed).
		              (#msg -> msg).
		              (#pos -> pos) } asDictionary ].
	tree := type = 'code'
		        ifTrue: [ RBParser parseExpression: source onError: errBlock ]
		        ifFalse: [ RBParser parseMethod: source onError: errBlock ].
	^ {
		  (#status -> #success).
		  (#source -> tree formattedCode) } asDictionary
]

{ #category : #accessing }
LiterateServer class >> methodSource: className name: methodName side: side [

	| class method |
	class := Smalltalk at: className asSymbol.
	class := side = #class
		         ifTrue: [ class class ]
		         ifFalse: [ class ].
	method := class methodDictionary at: methodName asSymbol.
	^ {
		  (#status -> #success).
		  (#source -> method sourceCode) } asDictionary
]

{ #category : #accessing }
LiterateServer class >> namespaces [

	| names |
	names := (Smalltalk globals allClasses collect: [ :each |
		          each category asString ]) asSet asSortedCollection.
	^ { (#status -> #success). (#namespaces -> names) } asDictionary
]

{ #category : #accessing }
LiterateServer class >> packageExtensions: packageName [

	| package methods |
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

{ #category : #accessing }
LiterateServer class >> packageTags: packageName [

	| package tags |
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

{ #category : #accessing }
LiterateServer class >> packages [

	^ {
		  (#status -> #success).
		  (#packages -> RPackageOrganizer default packageNames) } asDictionary
]

{ #category : #compile }
LiterateServer class >> removeClass: className [

	| class |
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

{ #category : #compile }
LiterateServer class >> removeSelector: className name: methodName side: side [

	| class status message |
	class := Smalltalk at: className asSymbol.
	class := side = #class
		         ifTrue: [ class class ]
		         ifFalse: [ class ].
	status := #success.
	message := ''.
	[ class removeSelector: methodName asSymbol]
		on: Exception
		do: [ :ex |
			message := ex asString.
			status := ex className ].
	^ {
		  (#status -> status).
		  (#message -> message) } asDictionary
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
	Transcript removeDependent: self.
	Transcript addDependent: self.
	teapot := Teapot configure: {
			          (#defaultOutput -> #json).
			          (#port -> 9092).
			          (#debugMode -> true).
			          (#bindAddress -> #[ 127 0 0 1 ]) }.
	teapot server logLevel: 1.
	self server: teapot.
	teapot
		GET: '/namespaces' -> [ :req | self namespaces ];
		GET: '/classes/<namespace>' -> [ :req | self classes: (req at: #namespace) ];
		GET: '/packages' -> [ :req | self packages ];
		GET: '/package/tags/<package>' -> [ :req | self packageTags: (req at: #package) ];
		GET:
			'/package/extensions/<package>'
			-> [ :req | self packageExtensions: (req at: #package) ];
		GET: '/class/<class>' -> [ :req | self classDef: (req at: #class) ];
		GET: '/cats/<class>' -> [ :req | self classCats: (req at: #class) ];
		GET: '/cat/methods'
			-> [ :req |
				self catMethods: (req at: #class) category: (req at: #cat) side: (req at: #side) ];
		GET: '/method/source'
			-> [ :req |
				self methodSource: (req at: #class) name: (req at: #name) side: (req at: #side) ];
		GET: '/method/remove' -> [ :req |
				self removeSelector: (req at: #class) name: (req at: #name) side: (req at: #side) ];
		POST: '/eval'
			-> [ :req | self evalCode: (req at: #code) openInspector: (req at: #inspector) = #true ];
		GET: '/eval/bindings' -> [ :req | self evalBindings ];
		GET: '/remove/class' -> [ :req | self removeClass: (req at: #class) ];
		POST: '/compile/class' -> [ :req |
				self
					compileClass: (NeoJSONReader fromString: (req at: #instance))
					class: (NeoJSONReader fromString: (req at: #class)) ];
		POST: '/compile/method' -> [ :req |
				self
					compileMethod: (req at: #class)
					category: (req at: #category)
					source: (req at: #source)
					side: (req at: #side) ];
		POST:
			'/format/code' -> [ :req | self formatCode: (req at: #source) type: (req at: #type) ];
		POST: '/completion/method'
			-> [ :req | self completion: (req at: #class) source: (req at: #source) ];
		exception: Exception -> [ :ex :req |
				self bringToFront.
				ex pass.
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
	(transcriptLogStream isNil or: transcriptLogStream closed) ifTrue: [
		transcriptLogStream := ((OSEnvironment current at: 'HOME')
		                        , '/.cache/literate-smalltalk/transcript.log') asFileReference
			                       writeStream.
		transcriptLogStream setToEnd ].
	transcriptLogStream print: Transcript contents.
	transcriptLogStream flush
]
