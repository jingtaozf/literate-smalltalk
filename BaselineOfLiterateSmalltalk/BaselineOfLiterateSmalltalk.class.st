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
			baseline: 'Teapot' with: [
				spec
					repository: 'github://zeroflag/Teapot:v2.6.0/source';
					loads: #( 'Deployment' ) ];
			import: 'Teapot'.
		spec
			package: 'LiterateSmalltalk'
			with: [ spec requires: #( 'Teapot' ) ].
		spec group: 'default' with: #( 'LiterateSmalltalk' ) ]
]
