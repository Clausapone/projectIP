%leggo il file excel
T = readtable('ulivi_in_CROP1_RGB.xlsx');
expolat = T.expolat;
expolon = T.expolon;

%trasformo le coordinate nel file excel in intrinseche
[A,RA] = readgeoraster('Seg_CROP1.tif');
proj = RA.ProjectedCRS;
proj.GeographicCRS.Name;
[ xt , yt ] = projfwd( proj , expolat , expolon );

[xInt, yInt] = worldToIntrinsic(RA,xt,yt);

xInt=uint16(xInt);
yInt=uint16(yInt);

punti = [xInt, yInt];


% -----------------------------------------------------------------------
% importo la maschera binaria e associo un ID a ogni chioma
mask = imread("Seg_CROP1.tif");
[L, num] = bwlabel(mask);

% creo un vettore per tenere traccia degli ID delle chiome presenti nel
% database tra il totale delle chiome nel crop
id_chiome = [];

%per ogni punto verifico a quale chioma appartiene
for i = 1:size(punti, 1)
    % Estraggo l'ID del cluster per il punto corrente
    id = L(punti(i,2), punti(i,1));
    if id ~= 0
        id_chiome = [id_chiome, id];
    end
end

% Creo una nuova maschera binaria ma con le sole chiome nel database
new_mask = ismember(L, id_chiome);
imshow(new_mask);


% ----------------------------------------------------------------------
% la uso per filtrare 'CROP1 47 1'
img = imread("CROP1_47 1.tif");
img = mat2gray(img(:,:,45));

new_mask = mat2gray(new_mask);

% ottengo un immagine con le sole chiome selezionate nel db (della banda
% numero 45)
result = new_mask .* img;
imshow(result);
