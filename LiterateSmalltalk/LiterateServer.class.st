"
The REST Server for LiterateSmalltalk.
"
Class {
	#name : #LiterateServer,
	#superclass : #Object,
	#classVars : [
		'Server',
		'Started'
	],
	#category : #LiterateSmalltalk
}

{ #category : #utilities }
LiterateServer class >> asStringArray: items [

	^ (items collect: [ :each | each asString ]) asArray
]

{ #category : #accessing }
LiterateServer class >> catMethods: className category: cat side: side [

	| class methods allMethods |
	class := Smalltalk at: className asSymbol.
	side = #class ifTrue: [ class := class class ].

	allMethods := class methodDictionary
		              ifNil: [ #(  ) ]
		              ifNotNil: [ :x | x associations ].

	methods := cat = '*'
		           ifTrue: [ allMethods ]
		           ifFalse: [
		           allMethods select: [ :e | e value category = cat ] ].
	^ { (#methods
	   ->
	   (methods collect: [ :each | each key asString ])
		   asSortedCollection) } asDictionary
]

{ #category : #accessing }
LiterateServer class >> classCats: className [

	| class cats result |
	result := Dictionary new.
	class := Smalltalk at: className asSymbol.
	cats := Set new.
	class methodDictionary ifNotNil: [ :d |
		d values do: [ :each | cats add: each category ] ].

	result at: #instance put: cats.

	class := class class.
	cats := Set new.
	class methodDictionary ifNotNil: [ :d |
		d values do: [ :each | cats add: each category ] ].
	result at: #class put: cats.
	^ result
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
	^ result
]

{ #category : #accessing }
LiterateServer class >> classes: namespace [

	| resultList |
	resultList := Smalltalk globals allClasses select: [ :each |
		              each category asString = namespace ].
	^ { (#classes -> (resultList collect: [ :each | each name asString ])) }
		  asDictionary
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
			Transcript
				show: e printString;
				cr.
			status := #failed ].

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

	| class result |
	class := Smalltalk at: className asSymbol.
	side = #class ifTrue: [ class := class class ].

	result := #success.
	[ class compile: source classified: cat ] onErrorDo: [ result := #failed ].
	^ { (#result -> result) } asDictionary
]

{ #category : #utilities }
LiterateServer class >> elementsString: items [

	^ items inject: '' into: [ :acc :each | acc , each asString , ' ' ]
]

{ #category : #compile }
LiterateServer class >> evalCode: code [

	| status result |
	status := #success.
	result := [
	          OpalCompiler new
		          source: code;
		          evaluate ] onErrorDo: [ result := #failed ].
	^ {
		  (#result -> result).
		  (#status -> status) } asDictionary
]

{ #category : #compile }
LiterateServer class >> formatCode: source [

	| tree |
	tree := RBParser
		        parseMethod: source
		        onError: [ :msg :pos |
		        ^ { #status -> #failed. #msg -> msg. #pos -> pos } asDictionary ].
	^ {
		  (#status -> #success).
		  (#source -> tree formattedCode) } asDictionary
]

{ #category : #accessing }
LiterateServer class >> methodSource: className name: name side: side [

	| class method |
	class := Smalltalk at: className asSymbol.
	side = #class ifTrue: [ class := class class ].
	method := class methodDictionary at: name asSymbol.
	^ { (#source -> method sourceCode) } asDictionary
]

{ #category : #accessing }
LiterateServer class >> namespaces [

	| names |
	names := (Smalltalk globals allClasses collect: [ :each |
		          each category asString ]) asSet asSortedCollection.
	^ { (#namespaces -> names) } asDictionary
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
	teapot := Teapot configure: {
			          (#defaultOutput -> #json).
			          (#port -> 9092).
			          (#debugMode -> true).
			          (#bindAddress -> #[ 127 0 0 1 ]) }.
	self server: teapot.
	teapot
		GET: '/namespaces' -> [ :req | self namespaces ];
		GET: '/classes/<namespace>'
			-> [ :req | self classes: (req at: #namespace) ];
		GET: '/class/<class>' -> [ :req | self classDef: (req at: #class) ];
		GET: '/cats/<class>' -> [ :req | self classCats: (req at: #class) ];
		GET: '/cat/methods' -> [ :req |
				self
					catMethods: (req at: #class)
					category: (req at: #cat)
					side: (req at: #side) ];
		GET: '/method/source' -> [ :req |
				self
					methodSource: (req at: #class)
					name: (req at: #name)
					side: (req at: #side) ];
		POST: '/eval' -> [ :req | self evalCode: (req at: #code) ];
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
			'/format/code' -> [ :req | self formatCode: (req at: #source) ];
		exception:
			KeyNotFound -> (TeaResponse notFound body: 'No such method');
		start.

	Started := true
]
