# Dispositif
# EXperimental de
# Timestamping
# Electronique
# Réprouvable

# VisualStudio Code : Reopen with encoding ISO 8859-1
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

$Repertoire      = "E:\Dexter"          # Répertoire de travail du script
$CheminOpenSSL   = "C:\OpenSSL\SSL\"    # Chemin du binaire OpenSSL sur la machine
$DelaiMilliSec   = 2000                 # Durée des temps de sommeil "simulés"

if ($env:PATH -notmatch [regex]::Escape($CheminOpenSSL)) { $env:PATH += ";$CheminOpenSSL" }   # Ajout du chemin d'OpenSSL dans le PATH

# Emplactements des fichiers de référence

$RepReference    = "$Repertoire\Filesystem"

$FichierDonut    = "$RepReference\Donuts.txt"
$FichierConserve = "$RepReference\Donuts_CONSERVE.txt"

# Emplacement des fichiers de requête / réponse TSA

$RepTSA          = "$Repertoire\FreeTSA"
$FichierTSQ      = "$RepTSA\file.tsq"
$FichierTSR      = "$RepTSA\file.tsr"

# Emplacement des fichiers de certificats (ils sont récupérés par le script)

$CertificatTSA   = "$RepTSA\tsa.crt"
$CertificatCA    = "$RepTSA\cacert.pem"

# URL des éléments extérieurs de la TSA

$UrlAPI          = "https://freetsa.org/tsr"
$UrlCertifTSA    = "https://freetsa.org/files/tsa.crt"
$UrlCertifCA     = "https://freetsa.org/files/cacert.pem"

# Fonction qui affiche les informations sur un fichier local (Nom, Date, Taille, Hash SHA-512)

function Afficher-Infos-Fichier
{
    param (
        [string]$CheminFichier
    )
    # Vérifie si le fichier existe
    if (-not (Test-Path -Path $CheminFichier -PathType Leaf)) {
        Write-Error "Le fichier '$CheminFichier' n'existe pas."
        return $null
    }
	$Fichier = Get-Item $CheminFichier
	$DateFichier = $Fichier.LastWriteTime
	$TailleFichier = $Fichier.Length

	Write-Host "Fichier : $CheminFichier" 		-ForeGroundColor Green
	Write-Host "Date :    $DateFichier" 		-ForeGroundColor Red

    if (($CheminFichier.Substring($CheminFichier.Length - 4) -ne ".TSQ") -and ($CheminFichier.Substring($CheminFichier.Length - 4) -ne ".TSR")) {

		$HashFichier = Get-FileHash -Path $CheminFichier -Algorithm SHA512
        $LeHash = $HashFichier.Hash


		Write-Host "Taille :  $TailleFichier octets" -ForeGroundColor Cyan
		Write-Host "Hash :    $LeHash" -ForeGroundColor Yellow
		Write-Host ""
		return $LeHash
	}
	else {
		return $null
	}

}

# Fonction qui permet de simuler un sommeil d'un instant pour générer des actions avec des secondes affichées différentes.

function Dormir-Un-Instant {
    param (
        [int]$Pendant
    )
    
    # Nombre de pas (chaque étape représente 10%)
    $steps = 20
    # Durée de chaque étape (diviser $Pendant par le nombre de pas)
    $stepDuration = $Pendant / $steps

    # Initialisation de la barre de progression
    for ($i = 1; $i -le $steps; $i++) {
        $progress = ($i * 5)  # Calcul du pourcentage de progression
        $bar = "." * $i         # Créer la barre de progression
        $spaces = " " * ($steps - $i)  # Espaces restants
        
        # Effacer la ligne précédente et afficher la nouvelle barre de progression sur la même ligne
        Write-Host -NoNewline "`rJe dors...$bar$spaces $progress %"

        # Attente avant de passer à l'étape suivante
        Start-Sleep -Milliseconds $stepDuration
    }

    # Fin de la barre de progression
    Write-Host ""
}

# Fonction qui simule une modification sur un fichier en ajoutant une ligne.

function Alterer-Fichier {
    param (
        [string]$Fichier
    )

    # Vérifie si le fichier existe
    if (-not (Test-Path -Path $Fichier -PathType Leaf)) {
        Write-Error "Le fichier '$Fichier' n'existe pas."
        return $null
    }

    try {
        # Ajoute la ligne au fichier
        if ((Get-Random -Maximum 2) -eq 0) {
           "Ajout d'un donut dans la boîte" | Out-File -FilePath $Fichier -Append
        } else {
           "Suppression d'un donut dans la boîte" | Out-File -FilePath $Fichier -Append
        }
        Write-Host "Une ligne a été ajoutée au fichier '$Fichier'." -ForegroundColor Green
    } catch {
        Write-Error "Une erreur est survenue lors de l'ajout de la ligne au fichier : $_"
        return $null
    }
}

# Fonction qui fait la comparaison de deux hashs passés en paramètre et présente le résultat.
# Nota : powershell est insensible à la casse et visuellement c'est encore mieux.

function Comparer-Deux-Hashs {
    param (
        [string]$Hash1,
        [string]$Hash2
    )
   
    $localTime = Get-Date
Write-Host "=========================================================================================================================================="
    Write-Host "Heure locale : $localTime" -ForegroundColor Red
    Write-Host "Hash 1 :  $Hash1" -ForegroundColor Yellow
    Write-Host "Hash 2 :  $Hash2" -ForegroundColor Yellow

    if ($Hash1 -eq $Hash2) {
        Write-Host "COMPARAISON : Les deux hashs sont identiques : le fichier est similaire." -ForegroundColor Green
    } else {
        Write-Host "COMPARAISON : Les hashs sont différents : le fichier a été altéré." -ForegroundColor Red
    }
    Write-Host "=========================================================================================================================================="
    Write-Host ""
}

# Fonction qui présente une partie des informations contenues dans un certificat

function Extraire-Infos-Certificat-Concise {
    param(
        [string]$CertificatFile
    )
    $Fichier = Get-Item $CertificatFile
	$DateFichier = $Fichier.LastWriteTime
    $NomDuCertificat = $Fichier.Name

    Write-Host "`n=== Infos certificat $NomDuCertificat ===" -ForegroundColor Cyan
    $subject   = openssl x509 -in $CertificatFile -noout -subject
    $issuer    = openssl x509 -in $CertificatFile -noout -issuer
    $startdate = openssl x509 -in $CertificatFile -noout -startdate
    $enddate   = openssl x509 -in $CertificatFile -noout -enddate
    Write-Host "Fichier :        $CertificatFile" -ForegroundColor Green
	Write-Host "Date :           $DateFichier" -ForeGroundColor Red
    Write-Host "Émetteur :       $issuer" -ForegroundColor Magenta
    Write-Host "Sujet :          $subject" -ForegroundColor Magenta
    Write-Host "Début validité : $startdate" -ForegroundColor Magenta
    Write-Host "Expiration :     $enddate" -ForegroundColor Magenta
}

# Fonction qui extrait les informations d'un fichier 'TimeStamp Response' (TSR)

function Extraire-Infos-TSR {

    Write-Host "`n=== Extraction des informations du fichier TSR ===" -ForegroundColor Cyan

    $FichierTSRInfo = Get-Item -Path "$FichierTSR"
    Write-Host "Fichier TSR de référence : $($FichierTSRInfo.FullName) [$(Get-Date -Date $FichierTSRInfo.LastWriteTimeUtc -Format 'MMM dd HH:mm:ss yyyy')] GMT" -ForegroundColor Green
    
    # Conversion du TSR en texte
    $tsOutput = openssl ts -reply -in $FichierTSR -text
    
    Write-Host "`n$tsOutput" -ForegroundColor Yellow

    # Découpage de la sortie en lignes
    $lines = $tsOutput -split "`n"
    # Rechercher la ligne "Message data:" et démarrer à la ligne suivante
    $startIndex = (($lines | Select-String -Pattern "Message data:").LineNumber)
    $hashHex = ""
    if ($startIndex) {
        # Commencer à la ligne suivante (en ajoutant 1)
        for ($i = $startIndex ; $i -lt $lines.Length; $i++) {
            # Arrêter si on atteint la ligne "Serial number:"
            if ($lines[$i] -match "Serial number:") { break }
            # Extraire les lignes commençant par un offset (ex: "0000 - ...")
            if ($lines[$i] -match "^\s*\d{4}\s*-\s*([0-9a-fA-F\s-]+)") {
                $part = $matches[1]
                # Supprimer espaces et tirets
                $part = $part -replace "[-\s]", ""
                $hashHex += $part
            }
        }
        $hashHex = $hashHex.ToLower()
    }

    # Extraction du timestamp : rechercher la ligne commençant par "Time stamp:"
    $timestampLine = $lines | Where-Object { $_ -match "Time stamp:" }
    $timestamp = ""
    if ($timestampLine) {
        $timestamp = $timestampLine -replace ".*Time stamp:\s*", ""
    }

    Write-Host "`n=== Résumé des informations d'horodatage FreeTSA ===" -ForegroundColor Cyan
    Write-Host "Fichier de référence :                 $FichierTSR" -ForegroundColor Green
    Write-Host "Hash contenu dans la réponse FreeTSA : $hashHex" -ForegroundColor Yellow
    Write-Host "Timestamp de la réponse FreeTSA :      $timestamp" -ForegroundColor Red

    return @{ "hash" = $hashHex; "timestamp" = $timestamp }
}

# Fonction qui affiche le comptenu d'un répertoire

function Lister-ContenuRepertoire {
    param (
        [string]$Repertoire
      )
    
      # Vérifie si le répertoire existe
      if (!(Test-Path -Path $Repertoire -PathType Container)) {
        Write-Error "Le répertoire '$Repertoire' n'existe pas."
        return
      }
    
      # Liste les fichiers du répertoire et affiche les détails sous forme de tableau
      Write-Host "=== Détails des fichiers dans le répertoire '$Repertoire': ===" -ForegroundColor Cyan 
      Get-ChildItem -Path $Repertoire -File | Select-Object @{Name="Nom du fichier";Expression={$_.Name}}, @{Name="Taille (o)";Expression={$_.Length}}, @{Name="Dernière modification";Expression={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')}}, @{Name="Date de création";Expression={$_.CreationTime.ToString('yyyy-MM-dd HH:mm:ss')}} | Format-Table -AutoSize
}


# Exemple d'utilisation :
Lister-ContenuRepertoire -Repertoire "C:\chemin\vers\repertoire"


# Fonction qui affiche un menu 

function Show-Menu {    
    Write-Host ""
	Write-Host "================ DEXTER =================" -ForegroundColor DarkRed
    Write-Host " 1. Simulation avec hash local          " 
    Write-Host " --------------------------------------- " -ForegroundColor DarkRed
	Write-Host " 2. Récupération des certificats FreeTSA "
    Write-Host " 3. Requête de timestamping FreeTSA      "
    Write-Host " 4. Vérification du hash du fichier      "
    Write-Host " 5. Altération du fichier                "
    Write-Host " 6. Restauration du fichier              "
    Write-Host " 7. État des répertoires                 "
    Write-Host " 0. Quitter                              "
    Write-Host "=========================================" -ForegroundColor DarkRed
	Write-Host ""
}


function Action-1 { 
	Write-Host "==========================" -ForegroundColor Red
	Write-Host " Simulation de hash local " -ForegroundColor White
	Write-Host "==========================" -ForegroundColor Red	

	Write-Host "Cette fonction simule les effets de l'Altération d'un fichier sur son hash sans faire appel à une autorité de timestamping" -ForegroundColor Yellow

	$Hash1=Afficher-Infos-Fichier $FichierDonut
    Dormir-Un-Instant -Pendant $DelaiMilliSec
    
    $Hash2 = Afficher-Infos-Fichier $FichierDonut
	
    Comparer-Deux-Hashs $Hash1 $Hash2

    Alterer-Fichier 	   $FichierDonut
    Dormir-Un-Instant -Pendant $DelaiMilliSec

    $Hash3 = Afficher-Infos-Fichier $FichierDonut

    Comparer-Deux-Hashs $Hash1 $Hash3

}

function Action-2 { 
	Write-Host "=====================================" -ForegroundColor Red
	Write-Host " Récupération des certificats FreeTSA" -ForegroundColor White
	Write-Host "=====================================" -ForegroundColor Red


	Write-Host "Cette fonction récupère les certificats TSA et CA de FreeTSA.org " -ForegroundColor Yellow
    Write-Host "Elle affiche leur contenu" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== (1) Récupération des certificats auprès de la CA ===" -ForegroundColor Cyan
    Write-Host "===     Cerficat de l'Autorité de Certification (CA) ===" -ForegroundColor Cyan
    Write-Host ""
    try {
        curl -o "$CertificatCA" "$UrlCertifCA"
        Write-Host "Certificat CA téléchargé avec succès à l'emplacement : $CertificatCA" -ForegroundColor Green
        Write-Host "Ce fichier contient le certificat de l'autorité de certification (CA) qui a signé le certificat de FreeTSA" -ForegroundColor Magenta
    }
    catch {
        Write-Error "Erreur lors du téléchargement du certificat CA : $($_.Exception.Message)" -ForegroundColor Red
        
    }
    Write-Host ""
    Write-Host "===   Cerficat de l'Autorité de Signature Temporelle (TSA) ===" -ForegroundColor Cyan
    Write-Host ""


    try {
        curl -o "$CertificatTSA" "$UrlCertifTSA"
        Write-Host "Certificat TSA téléchargé avec succès à l'emplacement : $CertificatTSA" -ForegroundColor Green
        Write-Host "Ce fichier contient le certificat de l'autorité de signature temporelle (TSA) elle-même" -ForegroundColor Magenta
    }
    catch {
        Write-Error "Erreur lors du téléchargement du certificat TSA : $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n=== (2) Vérification des certificats ===" -ForegroundColor Cyan
    Extraire-Infos-Certificat-Concise -CertificatFile $CertificatCA
    Extraire-Infos-Certificat-Concise -CertificatFile $CertificatTSA
}

function Action-3 { 
	Write-Host "=================================" -ForegroundColor Red
	Write-Host " Requête de timestamping FreeTSA " -ForegroundColor White	
	Write-Host "=================================" -ForegroundColor Red

	Write-Host "Cette fonction calcule le hash du fichier et le soumet à l'API de FreeTSA.org via un fichier .TSQ" -ForegroundColor Yellow
	Write-Host "Elle récupère ensuite un certificat de timestamping" -ForegroundColor Yellow
    Write-Host "Elle vérifie enfin la validité de ce certificat" -ForegroundColor Yellow

    # Étape 1 : Extraction initiale du hash local et envoi à FreeTSA
    
    Write-Host "`n=== (1) : Vérification initiale du hash ===" -ForegroundColor Cyan
    $hashInitial = Afficher-Infos-Fichier $FichierDonut 

    Write-Host "`n=== (2) : Création du fichier TSQ à partir du hash (SHA512) du fichier $FichierDonut ===" -ForegroundColor Cyan
    
    
    
     try {
        openssl ts -query -data $FichierDonut -no_nonce -sha512 -cert -out $FichierTSQ
        if (-not (Test-Path $FichierTSQ)) { throw "Le fichier TSQ n'a pas été généré." }
        Write-Host "`nFichier TSQ créé avec succès" -ForegroundColor Green
    } catch {
        Write-Error "`nErreur lors de la création du fichier TSQ : $_"
    }    
    
    $TailleFichier = (Get-Item $FichierTSQ).Length
    if ($TailleFichier -eq 0) {
        Write-Error "`nLe fichier TSQ est vide. La génération a échoué." -ForegroundColor Red
    }       
    else
    {
        $DateFichier = (Get-Item $FichierTSQ).LastWriteTime
        Write-Host "Fichier : $FichierTSQ"              -ForegroundColor Green
        Write-Host "Taille :  $TailleFichier octets" -ForegroundColor Cyan
        Write-Host "Date :    $DateFichier" 		 -ForeGroundColor Red

        Write-Host "Contenu du fichier TSQ :" -ForegroundColor DarkGreen

        $tsOutput = openssl ts -query -in "$FichierTSQ" -text
        Write-Host "`n$tsOutput" -ForegroundColor Yellow
    }

    Write-Host "`n=== (3) Soumission à FreeTSA ===`n" -ForegroundColor Cyan
    Write-Host "Envoi du TSQ à l'API d'horodatage..." -ForegroundColor Yellow

    
    try {
        $response = Invoke-WebRequest -Uri $UrlAPI -Method Post -InFile $FichierTSQ -ContentType 'application/timestamp-query' -OutFile $FichierTSR
        Write-Host "Réponse reçue de FreeTSA et enregistrée dans le fichier TSR : $FichierTSR" -ForegroundColor Green
    }
    catch {
        Write-Error "Erreur lors de l'envoi du fichier TSQ à l'API FreeTSA : $_" -ForegroundColor Red
    }





    $TailleFichier = (Get-Item $FichierTSR).Length

    if ($TailleFichier -eq 0) {
        Write-Error "`nLe fichier TSR est vide. La génération a échoué." -ForegroundColor Red
    }
    else 
    {
        $DateFichier = (Get-Item $FichierTSR).LastWriteTime
        Write-Host "Fichier : $FichierTSR"              -ForegroundColor Green
        Write-Host "Taille :  $TailleFichier octets" -ForegroundColor Cyan
        Write-Host "Date :    $DateFichier" 		 -ForeGroundColor Red
       

        Write-Host "`nContenu du fichier TSR :" -ForegroundColor DarkGreen

        $tsOutput = openssl ts -reply -in "$FichierTSR" -text
        Write-Host "`n$tsOutput" -ForegroundColor Yellow
    }


    Write-Host "`n=== (4) Vérification de l'authenticité du fichier $FichierTSR ===" -ForegroundColor Cyan

    openssl ts -verify -in $FichierTSR -queryfile $FichierTSQ -CAfile $CertificatCA -untrusted $CertificatTSA
    
    Write-Host "Création d'une copie de référence du fichier $FichierDonut vers $FichierConserve" -ForegroundColor Green

    Copy-Item -Path $FichierDonut -Destination $FichierConserve -Force
    $null = Afficher-Infos-Fichier $FichierConserve

}

function Action-4 { 
    Write-Host "=================================" -ForegroundColor Red
    Write-Host " Vérification du hash du fichier " -ForegroundColor White
    Write-Host "=================================" -ForegroundColor Red

    Write-Host "Cette fonction calcule le hash du fichier et le compare au hash certifié par FreeTSA" -ForegroundColor Yellow


    # 1. Vérification de la légitimité de la réponse TSA
    Write-Host "`n=== (1) : Vérification de la légitimité de la réponse TSA ===" -ForegroundColor Cyan
    Write-Host "Vérification de la signature du timestamp..." -ForegroundColor Yellow
    openssl ts -verify -in $FichierTSR -queryfile $FichierTSQ -CAfile $CertificatCA -untrusted $CertificatTSA
    if ($?) {
        Write-Host "La réponse TSA est légitime et valide." -ForegroundColor Green
    } else {
        Write-Error "La réponse TSA n'est pas valide." -ForegroundColor Red
    }

    # 2. Vérification du hash enregistré dans le fichier .TSR
    $tsrInfos = Extraire-Infos-TSR -TSRFile $FichierTSR
    $hashFreeTSA = $tsrInfos["hash"]
    $timestampFreeTSA = $tsrInfos["timestamp"]

    # 3. Affichage du hash local du fichier et de sa date
    Write-Host "`n=== (2) : Affichage du hash local du fichier ===" -ForegroundColor Cyan
    $HashLocal = Afficher-Infos-Fichier $FichierDonut

    # 4. Comparaison des hashs
    Write-Host "`n=== (3) : Comparaison des hashs ===" -ForegroundColor Cyan
    Comparer-Deux-Hashs $HashLocal $hashFreeTSA 


}

function Action-5 { 
	Write-Host "=======================" -ForegroundColor Red
	Write-Host " Altération du fichier " -ForegroundColor White
	Write-Host "=======================" -ForegroundColor Red
	
	Write-Host "Cette fonction altère le fichier en ajoutant une ligne" -ForegroundColor Yellow
    
    $null = Afficher-Infos-Fichier $FichierDonut
    Alterer-Fichier 	           $FichierDonut
    $null = Afficher-Infos-Fichier $FichierDonut

}

function Action-6 {
	Write-Host "=========================" -ForegroundColor Red
	Write-Host " Restauration du fichier " -ForegroundColor White
	Write-Host "=========================" -ForegroundColor Red	
    
	Write-Host "Cette fonction restaure le fichier dans sa version d'origine" -ForegroundColor Yellow

    $null = Afficher-Infos-Fichier $FichierDonut

    Write-Host "Cette fonction restauration du fichier $FichierConserve vers $FichierDonut" -ForegroundColor Green

    Copy-Item -Path $FichierConserve -Destination $FichierDonut -Force
    $null = Afficher-Infos-Fichier $FichierDonut
}

function Action-7 {
	Write-Host "======================" -ForegroundColor Red
	Write-Host " État des répertoires " -ForegroundColor White
	Write-Host "======================" -ForegroundColor Red	
    
	Write-Host "Cette fonction affiche le contenu du fichier de réference et des répertoires de travail" -ForegroundColor Yellow
    Write-Host ""
    $null=Afficher-Infos-Fichier $FichierDonut
  
    Get-Content -Path $FichierDonut | ForEach-Object { Write-Host $_ -ForegroundColor Green }

    Lister-ContenuRepertoire -Repertoire $RepReference
    Lister-ContenuRepertoire -Repertoire $RepTSA
}



Clear-Host

do {
    Show-Menu
    $choice = Read-Host "Entrez un chiffre (1-7) pour exécuter une action ou 0 pour quitter"
    
    switch ($choice) {
        "1" { Action-1 }
        "2" { Action-2 }
        "3" { Action-3 }
        "4" { Action-4 }
        "5" { Action-5 }
        "6" { Action-6 }
        "7" { Action-7 }
        "0" { Write-Host "Fermeture du programme..."; break }
        default { Write-Host "Choix invalide, veuillez entrer un chiffre entre 0 et 7." }
    }
    
#    if ($choice -ne "0") {
#        Write-Host "`nAppuyez sur Entrée pour revenir au menu..."
#        $null = Read-Host
#    }

} while ($choice -ne "0")
