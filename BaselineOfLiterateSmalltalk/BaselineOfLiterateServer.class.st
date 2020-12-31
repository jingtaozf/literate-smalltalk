Class {
	#name : #BaselineOfLiterateServer,
	#superclass : #BaselineOf,
	#category : #BaselineOfLiterateSmalltalk
}

{ #category : #'as yet unclassified' }
BaselineOfLiterateServer >> baselineOf: spec [
	<baseline>
	spec
		for: #common
		do: [
			self setUpDependencies: spec.
			spec package: 'LiterateSmalltalk' with: [ spec requires: #('Teapot') ].
			spec group: 'default' with: #('LiterateSmalltalk')]
]
