version 1.0

import "mutect2.wdl" as mutect2Workflow
import "tasks/common.wdl" as common
import "tasks/samtools.wdl" as samtools
import "tasks/somaticseq.wdl" as somaticSeqTask
import "strelka.wdl" as strelkaWorkflow
import "structs.wdl" as structs
import "vardict.wdl" as vardictWorkflow

workflow SomaticVariantcalling {
    input {
        String outputDir
        Reference reference
        String tumorSample
        IndexedBamFile tumorBam
        String? controlSample
        IndexedBamFile? controlBam
        TrainingSet? trainingSet
        File? regions

        Boolean runStrelka = true
        Boolean runVardict = true
        Boolean runMutect2 = true

        Map[String, String] dockerImages = {
            "picard":"quay.io/biocontainers/picard:2.18.26--0",
            "biopet-scatterregions":"quay.io/biocontainers/biopet-scatterregions:0.2--0",
            "tabix":"quay.io/biocontainers/tabix:0.2.6--ha92aebf_0",
            "manta": "quay.io/biocontainers/manta:1.4.0--py27_1",
            "strelka": "quay.io/biocontainers/strelka:2.9.7--0",
            "gatk4":"quay.io/biocontainers/gatk4:4.1.0.0--0",
            "vardict-java": "quay.io/biocontainers/vardict-java:1.5.8--1"
        }

        IndexedVcfFile? DONOTDEFINETHIS #FIXME
    }

    String mutect2Dir = outputDir + "/mutect2"
    String strelkaDir = outputDir + "/strelka"
    String vardictDir = outputDir + "/vardict"
    String somaticSeqDir = outputDir + "/somaticSeq"

    if (runMutect2) {
        call mutect2Workflow.Mutect2 as mutect2 {
            input:
                tumorSample = tumorSample,
                tumorBam = tumorBam,
                controlSample = controlSample,
                controlBam = controlBam,
                reference = reference,
                outputDir = mutect2Dir,
                regions = regions,
                dockerImages = dockerImages
        }
    }

    if (runStrelka) {
        call strelkaWorkflow.Strelka as strelka {
            input:
                controlBam = controlBam,
                tumorBam = tumorBam,
                reference = reference,
                outputDir = strelkaDir,
                basename = if defined(controlBam)
                    then "${tumorSample}-${controlSample}"
                    else tumorSample,
                regions = regions,
                dockerImages = dockerImages
        }
    }

    if (runVardict) {
        call vardictWorkflow.VarDict as vardict {
            input:
                tumorSample = tumorSample,
                tumorBam = tumorBam,
                controlSample = controlSample,
                controlBam = controlBam,
                reference = reference,
                outputDir = vardictDir,
                regions = regions,
                dockerImages = dockerImages
        }
    }

    if (defined(trainingSet) && defined(controlBam)) {
        #FIXME workaround for faulty 'no such field' errors which occur when a Struct is optional
        TrainingSet trainSetPaired = select_first([trainingSet])

        call somaticSeqTask.ParallelPairedTrain as pairedTraining {
            input:
                truthSNV = trainSetPaired.truthSNV,
                truthIndel = trainSetPaired.truthIndel,
                outputDir = somaticSeqDir + "/train",
                reference = reference,
                inclusionRegion = regions,
                tumorBam = trainSetPaired.tumorBam,
                normalBam = select_first([trainSetPaired.normalBam]),
                mutect2VCF = trainSetPaired.mutect2VCF,
                varscanSNV = trainSetPaired.varscanSNV,
                varscanIndel = trainSetPaired.varscanIndel,
                jsmVCF = trainSetPaired.jsmVCF,
                somaticsniperVCF = trainSetPaired.somaticsniperVCF,
                vardictVCF = trainSetPaired.vardictVCF,
                museVCF = trainSetPaired.museVCF,
                lofreqSNV = trainSetPaired.lofreqSNV,
                lofreqIndel = trainSetPaired.lofreqIndel,
                scalpelVCF = trainSetPaired.scalpelVCF,
                strelkaSNV = trainSetPaired.strelkaSNV,
                strelkaIndel = trainSetPaired.strelkaIndel,
                dockerImage = dockerImages["somaticseq"]
        }
    }

    if (defined(controlBam)) {
        call somaticSeqTask.ParallelPaired as pairedSomaticSeq {
            input:
                classifierSNV = pairedTraining.ensembleSNVClassifier,
                classifierIndel = pairedTraining.ensembleIndelsClassifier,
                outputDir = somaticSeqDir,
                reference = reference,
                inclusionRegion = regions,
                tumorBam = tumorBam,
                normalBam = select_first([controlBam]),
                mutect2VCF = if defined(mutect2.outputVCF)
                    then select_first([mutect2.outputVCF]).file
                    else DONOTDEFINETHIS,
                vardictVCF = if defined(vardict.outputVCF)
                    then select_first([vardict.outputVCF]).file
                    else DONOTDEFINETHIS,
                strelkaSNV = if defined(strelka.variantsVCF)
                    then select_first([strelka.variantsVCF]).file
                    else DONOTDEFINETHIS,
                strelkaIndel = if defined(strelka.indelsVCF)
                    then select_first([strelka.indelsVCF]).file
                    else DONOTDEFINETHIS,
                dockerImage = dockerImages["somaticseq"]
        }
    }

    if (defined(trainingSet) && !defined(controlBam)) {
        #FIXME workaround for faulty 'no such field' errors which occur when a Struct is optional
        TrainingSet trainSetSingle = select_first([trainingSet])

        call somaticSeqTask.ParallelSingleTrain as singleTraining {
            input:
                truthSNV = trainSetSingle.truthSNV,
                truthIndel = trainSetSingle.truthIndel,
                outputDir = somaticSeqDir + "/train",
                reference = reference,
                inclusionRegion = regions,
                bam = trainSetSingle.tumorBam,
                mutect2VCF = trainSetSingle.mutect2VCF,
                varscanVCF = trainSetSingle.varscanSNV,
                vardictVCF = trainSetSingle.vardictVCF,
                lofreqVCF = trainSetSingle.lofreqSNV,
                scalpelVCF = trainSetSingle.scalpelVCF,
                strelkaVCF = trainSetSingle.strelkaSNV,
                dockerImage = dockerImages["somaticseq"]
        }
    }

    if (!defined(controlBam)) {
        call somaticSeqTask.ParallelSingle as singleSomaticSeq {
            input:
                classifierSNV = singleTraining.ensembleSNVClassifier,
                classifierIndel = singleTraining.ensembleIndelsClassifier,
                outputDir = somaticSeqDir,
                reference = reference,
                inclusionRegion = regions,
                bam = tumorBam,
                mutect2VCF = if defined(mutect2.outputVCF)
                    then select_first([mutect2.outputVCF]).file
                    else DONOTDEFINETHIS,
                vardictVCF = if defined(vardict.outputVCF)
                    then select_first([vardict.outputVCF]).file
                    else DONOTDEFINETHIS,
                strelkaVCF = if defined(strelka.variantsVCF)
                    then select_first([strelka.variantsVCF]).file
                    else DONOTDEFINETHIS,
                dockerImage = dockerImages["somaticseq"]
        }
    }

    call samtools.BgzipAndIndex as snvIndex {
        input:
            inputFile = select_first([if defined(controlBam)
                then pairedSomaticSeq.snvs
                else singleSomaticSeq.snvs]),
            outputDir = somaticSeqDir,
            dockerImage = dockerImages["tabix"]
    }

    call samtools.BgzipAndIndex as indelIndex {
        input:
            inputFile = select_first([if defined(controlBam)
                then pairedSomaticSeq.indels
                else singleSomaticSeq.indels]),
            outputDir = somaticSeqDir,
            dockerImage = dockerImages["tabix"]

    }

    output{
        IndexedVcfFile somaticSeqSnvVcf =  object {
            file: snvIndex.compressed,
            index: snvIndex.index
        }
        IndexedVcfFile somaticSeqIndelVcf =  object {
            file: indelIndex.compressed,
            index: indelIndex.index
        }
        IndexedVcfFile? mutect2Vcf = mutect2.outputVCF
        IndexedVcfFile? vardictVcf = vardict.outputVCF
        IndexedVcfFile? strelkaSnvsVcf = strelka.variantsVCF
        IndexedVcfFile? strelkaIndelsVcf = strelka.indelsVCF
        IndexedVcfFile? mantaVcf = strelka.mantaVCF
    }
}