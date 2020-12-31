Class {
	#name : #LiterateServer,
	#superclass : #Object,
	#classVars : [
		'Server',
		'Started'
	],
	#category : #LiterateSmalltalk
}

{ #category : #'as yet unclassified' }
LiterateServer class >> catMethods: className category: cat side: side [
            | class methods allMethods result |
            class := Smalltalk at: className asSymbol.
            (side = #class) ifTrue: [class := class class].

            allMethods := class methodDictionary ifNil: [#()] ifNotNil: [:x | x associations].

            methods := (cat = '*'
                ifTrue: [allMethods]
                ifFalse: [allMethods select: [:e | e value category = cat]]).
	   ^ { #methods -> (methods collect: [:each | each key asString]) asSortedCollection } asDictionary
]

{ #category : #'as yet unclassified' }
LiterateServer class >> classCats: className [
    | class cats instanceSide classSide |
    result := Dictionary new.
    class := Smalltalk at: className asSymbol.
    cats := Set new.
    class methodDictionary ifNotNil: [:d | d values do:
	[:each | cats add: each category]].

    result at: #instance put: cats.

    class := class class.
    cats := Set new.
    class methodDictionary ifNotNil: [:d | d values do:
	[:each | cats add: each category]].
    result at: #class put: cats.
    ^ result
]

{ #category : #'as yet unclassified' }
LiterateServer class >> classDef: className [
	| class instanceSide classSide result |
	class := Smalltalk at: className asSymbol.
	instanceSide := Dictionary new.
	instanceSide at: #class put: className.
	instanceSide at: #superclass put: (class superclass printString).
	instanceSide at: #instvars put: (class instVarNames asStringArray).
	instanceSide at: #classvars put: (class classVarNames asStringArray).
	instanceSide at: #poolvars put: (class sharedPools asStringArray).
	instanceSide at: #package put: (class category).

	class := class class.
	classSide := Dictionary new.
	classSide at: #class put: className.
	classSide at: #superclass put: (class superclass printString).
	classSide at: #instvars put: (class instVarNames asStringArray).
	classSide at: #classvars put: (class classVarNames asStringArray).
	classSide at: #poolvars put: (class sharedPools asStringArray).
        result := Dictionary new.
	result at: #instance put: instanceSide.
	result at: #class put: classSide.
	^ result
]

{ #category : #'as yet unclassified' }
LiterateServer class >> classes: namespace [
    | resultList |
    resultList := Smalltalk allClasses select: [:each | each category asString = namespace].
    ^ { #classes -> (resultList collect: [:each | each name asString])} asDictionary
]

{ #category : #'as yet unclassified' }
LiterateServer class >> compileClass: instDef class: classDef [
    | parent class status instvars classvars |

    status := #success.
    instvars := ''.
    (instDef at: #instvars) ifNotNil: [ instvars := (instDef at: #instvars) elementsString ].

    classvars := ''.
    (instDef at: #classvars) ifNotNil: [ classvars := (instDef at: #classvars) elementsString ].

    "Looks a bit kludgy, but currently I dont know how to make it better. TODO: refactor"
    parent := Smalltalk at: ((instDef at: #super) asSymbol).
    [ class := parent
		    subclass: (instDef at: #name) asSymbol
		    instanceVariableNames: instvars
		    classVariableNames: classvars
		    poolDictionaries: ''
		    category: (instDef at: #package)
    ] on: Error do: [:e | Transcript show: e printString; cr. status := #failed ].

    class := Smalltalk at: (instDef at: #name) asSymbol ifAbsent: [nil].
    "On Pharo, there were a strange exception when using the safe form."
    instvars := ''.
    (classDef at: #instvars) ifNotNil: [ instvars := (classDef at: #instvars) elementsString ].
    class class instanceVariableNames: instvars.

    ^ {#status -> status} asDictionary.
]

{ #category : #compiling }
LiterateServer class >> compileMethod: className source: source side: side [
	| class result |
	class := (Smalltalk at: className asSymbol).
	(side = #class) ifTrue: [class := class class].

	result := #success.
	[class compile: source] onErrorDo: [ result := #failed ].
	^ {#result -> result} asDictionary
]

{ #category : #'as yet unclassified' }
LiterateServer class >> evalCode: code [
    | status result |
    status  := #success.
    result := [OpalCompiler new source: code; evaluate] onErrorDo:  [ result := #failed ].
    ^ {#result -> result. #status -> status} asDictionary
]

{ #category : #'as yet unclassified' }
LiterateServer class >> methodSource: className name: name side: side [
	| class method |
	class := Smalltalk at: className asSymbol.
	side = #class ifTrue: [ class := class class ].
	method := class methodDictionary at: name asSymbol.
	^ {#source -> method sourceCode} asDictionary
]

{ #category : #'as yet unclassified' }
LiterateServer class >> namespaces [
    | names |

    names := (Smalltalk allClasses collect: [:each | each category asString]) asSet asSortedCollection.
    ^ { #namespaces -> names } asDictionary
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

{ #category : #accessing }
LiterateServer class >> start [
	"Start the webserver"

	| teapot |

	"extra check so that we don't close a Pool which wasn't open"
	"Started ifNotNil: [ Started ifTrue: [ Server  stop ] ]."
	teapot := Teapot configure: {
			          (#defaultOutput -> #json).
			          (#port -> 9092).
			          (#debugMode -> true).
			          (#bindAddress -> #[ 127 0 0 1 ]) }.
	self server: teapot.
	teapot
	   GET: '/namespaces' -> [:req | self namespaces ];
	   GET: '/classes/<namespace>' -> [:req | self classes: (req at: #namespace) ];
	   GET: '/class/<class>' -> [:req | self classDef: (req at: #class) ];
	   GET: '/cats/<class>' -> [:req | self classCats: (req at: #class) ];
	   GET: '/cat/methods' -> [:req |
		self catMethods: (req at: #class)
		       category: (req at: #cat)
		       side: (req at: #side)
	    ];
	   GET: '/method/source' -> [:req |
		self methodSource: (req at: #class)
		       name: (req at: #name)
		       side: (req at: #side)
	    ];
	   POST: '/eval' -> [:req | self evalCode: (req at: #code)];
	   POST: '/compile/class' -> [:req |
		self compileClass: (NeoJSONReader fromString: (req at: #instance))
		     class: (NeoJSONReader fromString: (req at: #class))
	    ];
	   POST: '/compile/method' -> [:req |
		    self compileMethod: (req at: #class)
				source: (req at: #source)
				side: (req at: #side) ];
	   exception: KeyNotFound -> (TeaResponse notFound body: 'No such method');
	   start.

	Started := true.


]
