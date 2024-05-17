%leggo il file excel (Database) e ne ricavo latitudine e longitudine
Db = readtable('ulivi_in_CROP1_RGB.xlsx');
expolat = Db.expolat;
expolon = Db.expolon;
cultivar = Db.cult;


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


% creo un vettore per tenere traccia degli ID delle chiome presenti nel
% database tra il totale delle chiome nel crop
id_chiome_db = [];

lat = [];
lon = [];
cult = [];

%per ogni punto verifico a quale chioma appartiene
for i = 1:size(points, 1)
    % Estraggo l'ID del cluster per il punto corrente
    id = L(points(i,2), points(i,1));
    if id ~= 0
        id_chiome_db = [id_chiome_db, id];
        lat = [lat, expolat(i)];
        lon = [lon, expolon(i)];
        cult = [cult, cultivar(i)];
    end
end

% trasformo tutti i vettori in vettori colonna
id_chiome_db = reshape(id_chiome_db, [], 1);
cult = reshape(cult, [], 1);
cult = string(cult);
lat = reshape(lat, [], 1);
lon = reshape(lon, [], 1);

% ------------------------------------------------------------------
% Costruisco la matrice che conterrà lo spettro medio di ogni chioma
% escludendo gli outliers


% importo l'immagine multispettrale
Crop_img = imread("CROP1_47 1.tif");
num_bande = size(Crop_img, 3);

for i=1:length(id_chiome_db)
    id = id_chiome_db(i);
    for banda=1:num_bande
        
        Crop_temp = Crop_img(:,:,banda);
        
        % array che contiene tutti i valori di una chioma per una specifica banda
        Values = Crop_temp(L == id);
        
        mean = mean2(Values); 
        std = std2(Values);
        
        Values = Values( abs(Values - mean) <= 2 * std);

        Firma_spettrale_media(i, banda) = mean2(Values);
    end
end


%------------------------------------------------------------------------
% CREO LA TABELLA DA ESPORTARE CON LA FIRMA SPETTRALE MEDIA PER OGNI CHIOMA

% X sarà il database e Y la colonna degli outcomes
X = Firma_spettrale_media;
Y = cult;

Table = horzcat(id_chiome_db, lat, lon, X, Y);

% lables della tabella excel
labels = {'id_chioma', 'expolat', 'expolon'};
for banda = 1:num_bande
    labels = [labels, ['band_', num2str(banda)]];
end
labels = [labels, 'cult'];

Table = array2table(Table, 'VariableNames', labels);

writetable(Table, 'Ulivi_PROJECT.xlsx');


%------------------------------------------------------------------------
% EFFETTUO LA CLASSIFICAZIONE MULTICLASSE

% trasformo la colonna degli outcomes mappando le coltivazioni in numeri
Y = categorical(Y);
Y = double(Y);

% normalizzo con z-score il mio database
X = normalize(X);

% Holdout splitting con stratification
cv = cvpartition(Y, 'Holdout', 0.2, 'Stratify', true); 

train_index = training(cv);                         
X_Train = X(train_index, :);
Y_Train = Y(train_index);

test_index = test(cv);
X_Test = X(test_index, :);
Y_Test = Y(test_index);

% MODELLO: SVM
t = templateSVM('KernelFunction', 'linear', 'BoxConstraint', 1, 'Standardize', true);
Model = fitcecoc(X_Train, Y_Train, 'Learners', t);

Y_Pred_SVM = predict(Model, X_Test);

metrics = Classification_Metrics(Y_Test, Y_Pred_SVM);

% Visualizzazione delle metriche
fprintf('Accuracy: %.2f%%\n', metrics.Accuracy * 100);
fprintf('Precision: %.2f\n', metrics.Precision);
fprintf('Recall: %.2f\n', metrics.Recall);
fprintf('F1-Score: %.2f\n', metrics.F1Score);



% MODELLO: Random Forest 


% MODELLO: LDA




%{ 
Kfold splitting - OPZIONALE
cv = cvpartition(Y, 'KFold', 10);

for i = 1:cv.NumTestSets
    train_index = training(cv, i);
    test_index = test(cv, i);
    
    X_Train = X(train_index, :);
    Y_Train = Y(train_index);

    X_Test = X(test_index, :);
    Y_Test = Y(test_index);  

end
%}
