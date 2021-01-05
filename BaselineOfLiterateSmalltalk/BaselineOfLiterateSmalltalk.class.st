"
Baseline of LiterateSmalltalk.
"
Class {
	#name : #BaselineOfLiterateSmalltalk,
	#superclass : #BaselineOf,
	#category : #BaselineOfLiterateSmalltalk
}

{ #category : #baselines }
BaselineOfLiterateSmalltalk >> baselineOf: spec [

	<baseline>
	spec for: #common do: [
		spec
			package: 'LiterateSmalltalk'
			with: [ spec requires: #( 'Teapot' ) ].
		spec group: 'default' with: #( 'LiterateSmalltalk' ) ]
]
