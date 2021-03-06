###########################################
#Purpose: Code to run GSVA on data for a number of cancers
#Author: Pichai Raman
#Date: 2/14/2018
###########################################

#Call libraries
library("tidyverse");
library("GSVA");
library("cowplot");

#Read in clinical data
clinData <- read.delim("../data/PANCAN_clinicalMatrix")

#The top priority tumor types would be (in rough order), 
#Stomach adenocarcinoma (STAD), 
#Bladder (BLCA), 
#Esophageal (ESCA), 
#Melanoma (SKCM), 
#Breast (BRCA), and 
#Lung (LUAD and LUSC).  
#Because there’s a lot of tumors in BRCA 
#that express more TGFB3 than TGFB1, 
#I might expect that TGFB targets wouldn’t 
#track as clearly with TGFB1 as in some of the others.

#Let's pull out just these cancers 
myCancers <- c("lung adenocarcinoma", "lung squamous cell carcinoma", "esophageal carcinoma", "bladder urothelial carcinoma", "skin cutaneous melanoma", "stomach adenocarcinoma", "breast invasive carcinoma")
clinDataIH <- clinData %>% filter(X_primary_disease%in%myCancers)
rownames(clinDataIH) <- as.character(clinDataIH[,1])

#Read in data & update
data <- readRDS("../data/pancan12_GeneSymbol.RDS");

#Filter to diseases
commonSamps <- intersect(rownames(clinDataIH), colnames(data));
data <- data[,commonSamps];
clinDataIH <- clinDataIH[commonSamps,]

##################################################################
#Main Function: For each Disease we need to run GSVA across 500
#               random sets in addition to IPRES and TGFBeta Set
#               1. Distribution plot with red line for IPRES & TGFB1/2/3
#               2. Scatter plot of IPRES vs TGFB1/2/3
#               3. Scatter plot of TGFBeta set vs TGFB1/2/3
##################################################################
mylist <- list();
generateCorPlots <- function(myGene = "TGFB1", myCancer=NULL, myGeneSet=NULL, geneSetTitle="TGFBeta Geneset", n=500)
{
    #Filter to appropriate data
    clinDataTmp <- clinDataIH[clinDataIH[,"X_primary_disease"]%in%myCancer,]
    tmpData <- data[,rownames(clinDataTmp)]

    #How many genes are in geneset
    print(paste("There are ", length(myGeneSet), " genes in the gene set", sep=""));
    myGeneSet <- intersect(myGeneSet, rownames(tmpData))
    print(paste("There are ", length(myGeneSet), " genes in the intersection", sep=""));

    #Generate n random permutations with same number of genes
    randomGeneSetList <- list()
    for(i in 1:n)
    {
        tmpSample <- sample(rownames(tmpData), length(myGeneSet))
        randomGeneSetList[i] <- list(tmpSample);
    }
    names(randomGeneSetList)<- paste("RandomGeneSet_", c(1:n), sep="")
    randomGeneSetList$MyGeneSet <- myGeneSet

    #Run GSVA
    output_all <- gsva(as.matrix(tmpData), randomGeneSetList, abs.ranking=F)
    output <- data.frame(output_all);
    colnames(output) <- gsub("\\.", "-", colnames(output))

    #Print plots & Get Results
    #Correlation to myGene
    tmpForPlot <- data.frame(t(output["MyGeneSet",]), t(tmpData[myGene,]));
    tmpForPlot <- tmpForPlot[(tmpForPlot[,2]>log2(10)),]
    myCor <- cor.test(tmpForPlot[,1], tmpForPlot[,2]);
    myP <- myCor$p.value
    myCor <- myCor$estimate
    p1 <- ggplot(tmpForPlot, aes_string("MyGeneSet", myGene))+geom_point()+geom_smooth(method="lm")
    p1 <- p1+theme_bw()+xlab(geneSetTitle);
    p1 <- p1+ggtitle(paste(geneSetTitle, " vs ", myGene, " | Cor=", round(myCor, 2), " |  P=", formatC(myP, format = "e", digits = 2), sep=""))
    
    #Plot of distribution
    myCorAll <- cor(t(output), t(tmpData[myGene,]))
    p2 <- ggplot(data.frame(myCorAll), aes_string(myGene))+geom_histogram()+theme_bw();
    p2 <- p2+geom_vline(xintercept=myCor, color="red")+xlab("Cor");
    p2 <- p2+ggtitle(paste("Cor random sets vs ",myGene," ", geneSetTitle, " highlighted", sep=""))

    #Write out plots
    mylist[[paste(myCancer, "_", geneSetTitle, "_vs_", myGene, sep="")]] <<- c(myCancer, geneSetTitle, myGene, myP, myCor)
    myFileName <- paste(myCancer, "_", geneSetTitle, "_vs_", myGene, ".png", sep="")
    plot_grid(p1, p2)
    ggsave(myFileName, width=10, height=5)

}

#Read in Gene Sets
tgfbGeneSet <- as.character(read.delim("../data/tgfbGenes.txt")[,1])

for(i in 1:length(myCancers))
{
generateCorPlots(myGene="TGFB1", myCancers[i], myGeneSet=tgfbGeneSet, geneSetTitle="TGFBeta Geneset", n=99)
generateCorPlots(myGene="TGFB2", myCancers[i], myGeneSet=tgfbGeneSet, geneSetTitle="TGFBeta Geneset", n=99)
generateCorPlots(myGene="TGFB3", myCancers[i], myGeneSet=tgfbGeneSet, geneSetTitle="TGFBeta Geneset", n=99)
}

#Read in Gene Sets
plasariGeneSet <- as.character(read.delim("../data/PLASARI_TGFB1_TARGETS_10HR_UP.txt")[,1])

for(i in 1:length(myCancers))
{
generateCorPlots(myGene="TGFB1", myCancers[i], myGeneSet=plasariGeneSet, geneSetTitle="Plasari Geneset", n=99)
generateCorPlots(myGene="TGFB2", myCancers[i], myGeneSet=plasariGeneSet, geneSetTitle="Plasari Geneset", n=99)
generateCorPlots(myGene="TGFB3", myCancers[i], myGeneSet=plasariGeneSet, geneSetTitle="Plasari Geneset", n=99)
}

#Read in Gene Sets
ipresSet <- as.character(read.delim("../data/ipresGenes.txt")[,1])

for(i in 1:length(myCancers))
{
generateCorPlots(myGene="TGFB1", myCancers[i], myGeneSet=ipresSet, geneSetTitle="IPRES Geneset", n=99)
generateCorPlots(myGene="TGFB2", myCancers[i], myGeneSet=ipresSet, geneSetTitle="IPRES Geneset", n=99)
generateCorPlots(myGene="TGFB3", myCancers[i], myGeneSet=ipresSet, geneSetTitle="IPRES Geneset", n=99)
}

#Read in Gene Sets
teschDorffSig <- as.character(read.delim("../data/Teschendorff_TGFBeta.txt")[,1])


#Check if intersection is significant
runHypGeom <- function(set, genes,n=20000, universe=NULL)
{

if(!is.null(universe))
{
set <- intersect(set, universe);
}
#number of white balls
x <- length(intersect(genes, set));

#white balls
m <- length(genes);

#black balls
n2 <- n-m;

#balls drawn from the urn
k <- length(set);


out <- phyper(x-1, m, n2, k, lower.tail=F);
setSize <- k;
overLap <- x;
numGenes <- m;

myRet <- c(setSize, numGenes, overLap, out);
return(myRet);

}

runHypGeom(teschDorffSig, plasariGeneSet)


for(i in 1:length(myCancers))
{
generateCorPlots(myGene="TGFB1", myCancers[i], myGeneSet=teschDorffSig, geneSetTitle="Teschendorff Geneset", n=99)
generateCorPlots(myGene="TGFB2", myCancers[i], myGeneSet=teschDorffSig, geneSetTitle="Teschendorff Geneset", n=99)
generateCorPlots(myGene="TGFB3", myCancers[i], myGeneSet=teschDorffSig, geneSetTitle="Teschendorff Geneset", n=99)
}

output <- data.frame(t(data.frame(mylist)));
write.table(output, "pValsCorsTecsh.txt", sep="\t", row.names=F)







