  <?php
    $DOCUMENT_ROOT = $_SERVER['DOCUMENT_ROOT'];
    include_once("$DOCUMENT_ROOT/it/includes/common.inc");
    /* include_once("$DOCUMENT_ROOT/includes/functions.inc"); */
    print_header('Richiedere Aiuto', 'utf-8');
  ?>

	<div id="content">
		<h2 class="hdr">Richiedere Aiuto</h2>

		<p>Se durante l'utilizzo di DarwinPorts ti sei bloccato e non 
		riesci a risolvere un problema, abbiamo messo a disposizione diverse 
		risorse per aiutarti.</p>
	  
		<h5 class="subhdr">Documentazione</h5>

		<p>Nella <a href="http://darwinports.opendarwin.org/docs">
			Guida a DarwinPorts</a> è presente un'intera sezione 
			per l'utente <a href="http://darwinports.opendarwin.org/docs/pt01.html">
			Parte 1: Utilizzo di DarwinPorts</a>.</p>

		<p>A breve torneranno in linea anche le FAQ di DarwinPorts .</p>

		<p>Tutta la nostra documentazione è in continua evoluzione e, 
			quindi, se leggendo trovi un errore o hai dei dubbi circa 
			alcune parti di un documento, ti preghiamo di informarci! 
			Questo ci sarà sicuramente utile.</p>
	
		<h5 class="subhdr">Liste di discussione</h5>

		<p>La lista di discussione	
			<a href="http://www.opendarwin.org/mailman/listinfo/darwinports">
			darwinports</a> è aperta a tutti. È il posto 
			migliore per ricevere supporto e porre domande su DarwinPorts 
			per tutti, sia per i nuovi utenti, sia per gli sviluppatori.
			È anche il posto dove si discute dell'evoluzione del 
			progetto. A causa dello spam, se vuoi inviare un messaggio,
			ti preghiamo gentilmente di iscriverti alla lista.</p>

		<p>Prima di inviare una richiesta ti consigliamo di consultare l'
			<a href="http://www.opendarwin.org/pipermail/darwinports/">
			archivio della mailing list</a>	anche se ciò non è 
			necessariamente un dovere. Cercheremo il più possibile 
			di aiutarti, ma se le domande sono comuni le nostre risposte
			potrebbero essere abbastanza brevi.</p>

		<p>Quando invii un messaggio alla mailing list ti invitiamo ad includere 
			ogni informazione che pensi potrebbe essere rilevante ai fini 
			risolutivi del problema, come quale sistema operativo stai usando 
			(OS X 10.3.2, per esempio), se hai installato altro software di 
			terze parti nella directory /usr/local e qualsiasi messaggio di 
			errore hai ricevuto da DarwinPorts. Più informazioni darai 
			e più sarà semplice per noi aiutarti.</p>

		<h5 class="subhdr">IRC</h5>

		<p>Generalmente per le disccussioni in tempo reale siamo in ascolto sul 
			canale #opendarwin della <a href="http://freenode.net/">rete IRC 
			freenode</a>.</p>
	
		<p>Anche se puoi ricevere aiuto per favore tieni sempre a mente che
			nessuno è obbligato a rispondere. Quindi, nel caso non
			ricevessi risposta, non c'è niente di personale; potrai semplicemente 
			porre le tue domande scrivendo alla lista di discussione
			<a href="http://www.opendarwin.org/mailman/listinfo/darwinports">
			darwinports</a>.</p>

	</div>
</div>

<?php
  print_footer();
?>
