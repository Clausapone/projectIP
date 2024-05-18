rng(1);

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

figure;
imshow(Mask);
title('SEGMENTAZIONE DELLE CHIOME (MASCHERA BINARIA 1)');

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

% Creo una nuova maschera binaria ma con le sole chiome nel database
Mask2 = ismember(L, id_chiome_db);

figure;
imshow(Mask2);
title('SEGMENTAZIONE DELLE SOLE CHIOME PRESENTI NEL DATABASE (MASCHERA BINARIA 2)');


%----------------------------------------------------------------------
%ESEMPIO DI APPLICAZIONE DELLA MASCHERA ALLA BANDA NUMERO 47

% importo l'immagine multispettrale
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
        
        % array che contiene tutti i valori di una chioma per una specifica banda
        Values = Crop_temp(L == id);
        
        mean = mean2(Values); 
        std = std2(Values);
        
        Values = Values( abs(Values - mean) <= 2 * std);

        Firma_spettrale_media(i, banda) = mean2(Values);
    end
end


%---------------------------------------------------------------------
% VISUALIZZAZIONE DELLE FIRME SPETTRALI MEDIE DI ALCUNE LE CHIOME NEL
% DATABASE (NON TOTALMENTE ACCURATA)

for i=1:10:size(Firma_spettrale_media, 1)
    figure;
    plot(1:num_bande, Firma_spettrale_media(i,:));
    title('SPETTRO MEDIO DELLA CHIOMA CON ID:', id_chiome_db(i));
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

writetable(Table, 'Ulivi_Project_Crop1.xlsx');


%--------------------------------------------------------------------------
% EFFETTUO LA CLASSIFICAZIONE MULTICLASSE CON DIVERSI MODELLI


% trasformo la colonna degli outcomes mappando le coltivazioni in numeri
Y = categorical(Y);
cult_lables = unique(Y)';
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


% MODELLO: SVM (KERNEL LINEARE)
t = templateSVM('KernelFunction', 'linear', 'BoxConstraint', 1, 'Standardize', true);
SVM_Model = fitcecoc(X_Train, Y_Train, 'Learners', t);

Y_Pred_SVM = predict(SVM_Model, X_Test);

metrics = Classification_Metrics(Y_Test, Y_Pred_SVM, cult_lables);

% Visualizzazione delle metriche
fprintf('METRICHE DI VALUTAZIONE UTILIZZANDO SVM CON KERNEL LINEARE COME MODELLO\n');
fprintf('\nAccuracy: %.2f%%\n', metrics.Accuracy * 100);
fprintf('----------------\n');
fprintf('Precision: %.2f\n', metrics.Precision);
fprintf('----------------\n');
fprintf('Recall: %.2f\n', metrics.Recall);
fprintf('----------------\n');
fprintf('F1-Score: %.2f\n', metrics.F1Score);
fprintf('-----------------------------------------------------------------------------\n');


% MODELLO: SVM (KERNEL GAUSSIANO)
t = templateSVM('KernelFunction', 'gaussian', 'BoxConstraint', 1, 'Standardize', true);
SVM_Model = fitcecoc(X_Train, Y_Train, 'Learners', t);

Y_Pred_SVM = predict(SVM_Model, X_Test);

metrics = Classification_Metrics(Y_Test, Y_Pred_SVM, cult_lables);

% Visualizzazione delle metriche
fprintf('METRICHE DI VALUTAZIONE UTILIZZANDO SVM CON KERNEL GAUSSIANO COME MODELLO\n');
fprintf('\nAccuracy: %.2f%%\n', metrics.Accuracy * 100);
fprintf('----------------\n');
fprintf('Precision: %.2f\n', metrics.Precision);
fprintf('----------------\n');
fprintf('Recall: %.2f\n', metrics.Recall);
fprintf('----------------\n');
fprintf('F1-Score: %.2f\n', metrics.F1Score);
fprintf('-----------------------------------------------------------------------------\n');


% MODELLO: RANDOM FOREST
RF_Model = fitcensemble(X_Train, Y_Train, 'Method', 'Bag', 'Learners', 'tree', Options=statset(UseParallel=true));
Y_Pred_RF = predict(RF_Model, X_Test);


metrics = Classification_Metrics(Y_Test, Y_Pred_RF, cult_lables);

% Visualizzazione delle metriche
fprintf('METRICHE DI VALUTAZIONE UTILIZZANDO RANDOM FOREST COME MODELLO\n');
fprintf('\nAccuracy: %.2f%%\n', metrics.Accuracy * 100);
fprintf('----------------\n');
fprintf('Precision: %.2f\n', metrics.Precision);
fprintf('----------------\n');
fprintf('Recall: %.2f\n', metrics.Recall);
fprintf('----------------\n');
fprintf('F1-Score: %.2f\n', metrics.F1Score);
fprintf('-----------------------------------------------------------------------------\n');


% MODELLO: LDA (DISCRIMINANT TYPE: LINEAR)
opts = struct('ShowPlots', false, 'Verbose', 0);
LDA_Model = fitcdiscr(X_Train, Y_Train, 'DiscrimType', 'linear', 'OptimizeHyperparameters', 'auto', 'HyperparameterOptimizationOptions', opts);
Y_Pred_LDA = predict(LDA_Model, X_Test);

metrics = Classification_Metrics(Y_Test, Y_Pred_LDA, cult_lables);

% Visualizzazione delle metriche
fprintf('METRICHE DI VALUTAZIONE UTILIZZANDO LDA COME MODELLO (DISCRIMINANT TYPE: LINEAR)\n');
fprintf('\nAccuracy: %.2f%%\n', metrics.Accuracy * 100);
fprintf('----------------\n');
fprintf('Precision: %.2f\n', metrics.Precision);
fprintf('----------------\n');
fprintf('Recall: %.2f\n', metrics.Recall);
fprintf('----------------\n');
fprintf('F1-Score: %.2f\n', metrics.F1Score);
fprintf('-----------------------------------------------------------------------------\n');


% MODELLO: LDA (DISCRIMINANT TYPE: DIAGLINEAR)
LDA_Model = fitcdiscr(X_Train, Y_Train, 'DiscrimType', 'diaglinear', 'OptimizeHyperparameters','auto', 'HyperparameterOptimizationOptions', opts);
Y_Pred_LDA = predict(LDA_Model, X_Test);

metrics = Classification_Metrics(Y_Test, Y_Pred_LDA, cult_lables);

% Visualizzazione delle metriche
fprintf('METRICHE DI VALUTAZIONE UTILIZZANDO LDA COME MODELLO (DISCRIMINANT TYPE: DIAGLINEAR)\n');
fprintf('\nAccuracy: %.2f%%\n', metrics.Accuracy * 100);
fprintf('----------------\n');
fprintf('Precision: %.2f\n', metrics.Precision);
fprintf('----------------\n');
fprintf('Recall: %.2f\n', metrics.Recall);
fprintf('----------------\n');
fprintf('F1-Score: %.2f\n', metrics.F1Score);
fprintf('-----------------------------------------------------------------------------\n');


% MODELLO: LDA (DISCRIMINANT TYPE: PSEUDOLINEAR)
LDA_Model = fitcdiscr(X_Train, Y_Train, 'DiscrimType', 'pseudolinear', 'OptimizeHyperparameters','auto', 'HyperparameterOptimizationOptions', opts);
Y_Pred_LDA = predict(LDA_Model, X_Test);

metrics = Classification_Metrics(Y_Test, Y_Pred_LDA, cult_lables);

% Visualizzazione delle metriche
fprintf('METRICHE DI VALUTAZIONE UTILIZZANDO LDA COME MODELLO (DISCRIMINANT TYPE: PSEUDOLINEAR)\n');
fprintf('\nAccuracy: %.2f%%\n', metrics.Accuracy * 100);
fprintf('----------------\n');
fprintf('Precision: %.2f\n', metrics.Precision);
fprintf('----------------\n');
fprintf('Recall: %.2f\n', metrics.Recall);
fprintf('----------------\n');
fprintf('F1-Score: %.2f\n', metrics.F1Score);