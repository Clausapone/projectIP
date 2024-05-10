function metrics = Classification_Metrics(Y_true, Y_pred)

    confMat = confusionmat(Y_true, Y_pred);

    % Calcolo dell'accuratezza
    accuracy = sum(Y_pred == Y_true) / numel(Y_true);

    % Calcolo di precision, recall e F1-score
    for i = unique(Y_true)'
        tp = confMat(i,i);
        fp = sum(confMat(:,i)) - tp;
        fn = sum(confMat(i,:)) - tp;
        precision(i) = tp / (tp + fp);
        recall(i) = tp / (tp + fn);
        f1Score(i) = 2 * (precision(i) * recall(i)) / (precision(i) + recall(i));
    end

    % Salvataggio delle metriche in una struct
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