# Aggiunte da fare

## Comando init

Il comando init, adesso dovrà avere due modalità:

1. Modalità Brainstorming (Nuova)
2. Modalità inizializzazione

### Modalità Brainstorming

In questa modalità l'agente sarà un compagno di brainstorming, aiuterà lo sviluppatore a consigliare le migliori feature,
tecnologie, scelte di prodotto e architetturali. Alla fine del brainstorming, verrà compilato un file con tutte le scelte prese
e chiede se si vuole procedere con la modalità inizializzaione

### Modalità inizializzazione

In questa modalità, che è quella attuale, sarà possibile fornire un documento, tipo quello di brainstorming, di cui sopra.
Dal quel documento il comando vedrà se ha tutte le informazioni necessarie per l'init, altrimenti farà solo le domande
per completare il quadro delle informazioni.

## Refactor comandi

- devflow.clarify: Rimuovere come comando, ma lasciarlo come step opzionale
- devflow.analyze: Rimuovere come comando, ma lasciarlo come step opzionale
- devflow.beautify: Rimuovere come comando, ma lasciarlo come step opzionale chiesto durante l'implementazione `devflow.implement` o `devflow.auto`
