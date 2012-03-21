options(stringsAsFactors=FALSE)

exp <- read.csv(file = "day0.csv")

ctrl_k9 <- read.csv(file = "ctrl_h3k9ac_nearest_peak_to_gene_TSS.csv")

rest_k9 <- read.csv(file = "rest_h3k9ac_nearest_peak_to_gene_TSS.csv")

####pull out relevant columns into phat dataframe

exp_tidy <- exp[,c("EnsemblID", "symbol", "logFC","adj.P.Val")]

exp_res <- exp_tidy[which(!is.na(exp_tidy[,"EnsemblID"])),]

ctrl_k9_tidy <- ctrl_k9[,c("Peak","EnsemblID", "FoldEnrichment","FDR","neg10log10pVal", "distancetoFeature")]

rest_k9_tidy <- rest_k9[,c("Peak","EnsemblID", "FoldEnrichment","FDR","neg10log10pVal", "distancetoFeature")]

####merge all together via EnsemblID

res <- merge(exp_res, merge(ctrl_k9_tidy, rest_k9_tidy, by.x = "EnsemblID", by.y = "EnsemblID", suffixes = c("_ctrl","_rest")), by.x = "EnsemblID", by.y = "EnsemblID")

res_sig <- res[which(res[,"adj.P.Val"] <= 0.05),]

#####################Hmm this doesnt work - try DeSeq??

##via deseq

deseq <- read.csv(file = "peak_compare.csv")

deseq <- deseq[,c(1,2,3,4,5,6,7,8)]

res_deseq <- merge(res_sig, deseq, by.x = "Peak_rest", by.y = "id")


postscript(file = "H3K9ac_vs_expression.ps", horizontal = FALSE)
plot(res_deseq[,"log2FoldChange"], res_deseq[,"logFC"], pch= ".",xlab = "H3K9ac peak size between REST-KO and WT",ylab = "Gene expression changes between REST-KO and WT")
dev.off()
