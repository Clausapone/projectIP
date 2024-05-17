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
Crop_img = imread("CROP1_47.tif");
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

rng(1)

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


% metrics function
function metrics = Classification_Metrics(Y_true, Y_pred)

    confMat = confusionmat(Y_true, Y_pred);

    % Calcolo dell'accuratezza
    accuracy = sum(Y_pred == Y_true) / numel(Y_true);      % model 0 --> 62, model1 --> 54, model 0 per ora migliore con l' svm


    % Calcolo di precision, recall e F1-score
    for i = 1 : size(unique(Y_true), 1)
        tp = confMat(i,i);            % deve restituire gli elementi della diagonale - ok
        fp = sum(confMat(:, i)) - tp;  % ok
        fn = sum(confMat(i, :)) - tp;  % ok 
        precision(i) = tp / (tp + fp);    % concatenazione con questa sintassi
        recall(i) = tp / (tp + fn);       % non ho il numero di samples per la terza categoria
        f1Score(i) = 2 * (precision(i) * recall(i)) / (precision(i) + recall(i));        % precision e recall uguali a zero
    end 

    % Salvataggio delle metriche in una struttura dati apposita 
    metrics.Accuracy = accuracy;
    metrics.Precision = precision;
    metrics.Recall = recall;
    metrics.F1Score = f1Score;
    metrics.ConfusionMatrix = confMat;

    % Visualizzazione della matrice di confusione
    figure;
    confusionchart(confMat);
    title('Confusion Matrix');
end



%------------------------------------------------------------------------
% EFFETTUO LA CLASSIFICAZIONE MULTICLASSE

% trasformo la colonna degli outcomes mappando le coltivazioni in numeri
Y = categorical(Y);
Y = double(Y);

% Holdout splitting con stratification
cv = cvpartition(Y, 'Holdout', 0.2, 'Stratify', true);   

% Warning: One or more of the unique class values in GROUP is not present in the training set. For classification problems, either remove this class from the data or use N
% instead of GROUP to obtain nonstratified partitions. For regression
% problems with continuous response, use N. --> only one sample with 3


train_index = training(cv);                         
X_Train = X(train_index, :);
Y_Train = Y(train_index);

test_index = test(cv);
X_Test = X(test_index, :);
Y_Test = Y(test_index);

% MODELLO: SVM
t = templateSVM('KernelFunction', 'linear', 'BoxConstraint', 1, 'Standardize', true);   % Cross-Validation for C

t1 = templateSVM('KernelFunction', 'gaussian', 'BoxConstraint', 1, 'Standardize', true);

t2 = templateSVM('KernelFunction', 'rbf', 'BoxConstraint',1, 'Standardize', true);

t3 = templateSVM('KernelFunction', 'polynomial', 'BoxConstraint', 1, 'Standardize', true);


% Model = fitcecoc(X_Train, Y_Train, 'Learners', t);

% Model1 = fitcecoc(X_Train, Y_Train, 'Learners', t1);

% Model2 = fitcecoc(X_Train, Y_Train, 'Learners', t2);

% Model3 = fitcecoc(X_Train, Y_Train, 'Learners', t3);

% L = resubLoss(Model,"LossFun","classiferror")

% Y_Pred_SVM = predict(Model1, X_Test);

% Y_Pred_SVM = predict(Model1, X_Test);

% Y_Pred_SVM = predict(Model2, X_Test);

% Y_Pred_SVM = predict(Model3, X_Test);


% metrics = Classification_Metrics(Y_Test, Y_Pred_SVM);

% Visualizzazione delle metriche
% fprintf('Accuracy: %.2f%%\n', metrics.Accuracy * 100);
% fprintf('Precision: %.2f\n', metrics.Precision);        
% fprintf('Recall: %.2f\n', metrics.Recall);
% fprintf('F1-Score: %.2f\n', metrics.F1Score);



% MODELLO: Random Forest 1 - usign TreeBagger

% Creazione e addestramento del modello Random Forest
%{ 
numTrees = 100;  % Numero di alberi nella foresta
options = {'OOBPrediction', 'on', 'Method', 'classification','MinLeafSize', 5};
rfModel = TreeBagger(numTrees, X, Y, options{:});  

oobLabels = oobPredict(rfModel);
oobLabels = cell2mat(oobLabels);

for i = 1 : size(oobLabels, 1)
    pred(i) = str2double(oobLabels(i));

end

% Y_pred = reshape(pred,[177,1]) 

% metrics = Classification_Metrics(Y, Y_pred);


% MODELLO: Random Forest 2 - using ClassificationBaggedExample

%}


rfModel2 = fitcensemble(X_Train, Y_Train, 'Method', 'Bag', 'Learners', 'tree', Options=statset(UseParallel=true));  % bonus : check the hyperparameters and cv
Y_Pred = predict(rfModel2, X_Test);
metrics = Classification_Metrics(Y_Test, Y_Pred);



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