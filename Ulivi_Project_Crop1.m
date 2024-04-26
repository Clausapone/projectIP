%leggo il file excel (Database) e ne ricavo latitudine e longitudine
Db = readtable('ulivi_in_CROP1_RGB.xlsx');
expolat = Db.expolat;
expolon = Db.expolon;
cult = Db.cult;

% trasformo le coordinate geografiche nel database in intrinseche
[A,RA] = readgeoraster('Seg_CROP1.tif');
proj = RA.ProjectedCRS;
proj.GeographicCRS.Name;
[ xt , yt ] = projfwd( proj , expolat , expolon );

[xInt, yInt] = worldToIntrinsic(RA,xt,yt);

xInt=uint16(xInt);
yInt=uint16(yInt);

points = [xInt, yInt];


% -----------------------------------------------------------------------
% importo la maschera binaria e associo un ID a ogni cluster (chioma)
Mask = imread("Seg_CROP1.tif");
[L, num] = bwlabel(Mask);

figure;
imshow(Mask);
title('SEGMENTAZIONE DELLE CHIOME (MASCHERA BINARIA 1)');


% creo un vettore per tenere traccia degli ID delle chiome presenti nel
% database tra il totale delle chiome nel crop
id_chiome_db = [];

%per ogni punto verifico a quale chioma appartiene
for i = 1:size(points, 1)
    % Estraggo l'ID del cluster per il punto corrente
    id = L(points(i,2), points(i,1));     % uso y per le righe e x per le colonne - RICORDA LEZIONE GUERRIERO
    if id ~= 0
        id_chiome_db = [id_chiome_db, id];
    end
end

id_chiome_db = reshape(id_chiome_db, [], 1);    % lo trasformo in un vettore colonna


% Creo una nuova maschera binaria ma con le sole chiome nel database
Mask2 = ismember(L, id_chiome_db);

figure;
imshow(Mask2);
title('SEGMENTAZIONE DELLE SOLE CHIOME PRESENTI NEL DATABASE (MASCHERA BINARIA 2)');

%----------------------------------------------------------------------
%ESEMPIO DI APPLICAZIONE DELLA MASCHERA ALLA BANDA NUMERO 47 

% la uso per filtrare 'CROP1'
Crop_img = imread("CROP1_47 1.tif");
num_bande = size(Crop_img, 3);


% ottengo un immagine con le sole chiome presenti nel db (della banda
% numero 47)
New_Crop = Mask2 .* Crop_img(:,:,47);
figure;
imshow(New_Crop);
title('ESEMPIO - RISULTATO DELL APPLICAZIONE DELLA MASCHERA ALLA BANDA NUMERO 47');


% ------------------------------------------------------------------
% Costruisco la matrice che conterrà lo spettro medio di ogni chioma
% escludendo gli outliers

for i=1:length(id_chiome_db)
    id = id_chiome_db(i);
    for banda=1:num_bande
        
        Crop_temp = Crop_img(:,:,banda);

        Values = Crop_temp(L == id);    % array che contiene tutti i valori di 
        
        mean = mean2(Values); 
        std = std2(Values);
        
        Values = Values( abs(Values - mean) <= 2 * std);

        Firma_spettrale_media(i, banda) = mean2(Values);
    end
end

%---------------------------------------------------------------------
% VISUALIZZAZIONE DELLE FIRME SPETTRALI MEDIE DI TUTTE LE CHIOME NEL
% DATABASE

for i=1:10:size(Firma_spettrale_media, 1)
    figure;
    plot(1:num_bande, Firma_spettrale_media(i,:));
    title('SPETTRO MEDIO DELLA CHIOMA CON ID:', id_chiome_db(i));
end

%------------------------------------------------------------------------
% CREO LA TABELLA DA ESPORTARE CON LA FIRMA SPETTRALE MEDIA PER OGNI CHIOMA

Table = horzcat(id_chiome_db, Firma_spettrale_media);

% lables della tabella excel
lables = {'id_chioma'};
for banda = 1:num_bande
    lables = [lables, ['band_', num2str(banda)]];
end


Table = array2table(Table, 'VariableNames', lables);

writetable(Table, 'Ulivi_Project_Crop1.xlsx');

%-------------------------------------------------------------------------