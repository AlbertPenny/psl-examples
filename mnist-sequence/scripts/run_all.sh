#!/bin/bash

# Grid search over hyperparams.

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_OUT_DIR="${THIS_DIR}/../results"

readonly ADDITIONAL_PSL_OPTIONS='-D log4j.threshold=TRACE --postgres psl'

readonly BATCH_SIZES='064'
readonly LEARNING_RATES='00.01 00.10 00.50 01.00 02.00'
readonly EPOCHS='50 100 200 500'
readonly COMPUTE_PERIODS='010 020 050 100 200 300'
readonly RULE_SETS='single triple'
readonly ADMM_ITERATIONS=`seq -w 500 500 5000`

# Note that the first value in each of these sequences will apply no binarization.
readonly BIN_RANK_LOWER='0.00 0.11 0.21 0.31 0.41 0.51 0.61 0.71 0.81 0.91'
readonly BIN_RANK_UPPER='1.00 0.90 0.80 0.70'
readonly BIN_THRESHOLD_LOWER='0.00 0.10 0.20 0.30'
readonly BIN_THRESHOLD_UPPER='1.00 0.50 0.40 0.30 0.20'

function run_psl() {
    local cliDir=$1
    local outDir=$2
    local extraOptions=$3

    mkdir -p "${outDir}"

    local outPath="${outDir}/out.txt"
    local errPath="${outDir}/out.err"
    local timePath="${outDir}/time.txt"

    if [[ -e "${outPath}" ]]; then
        echo "Output file already exists, skipping: ${outPath}"
        return 0
    fi

    pushd . > /dev/null
        cd "${cliDir}"

        # Run PSL.
        /usr/bin/time -v --output="${timePath}" ./run.sh ${extraOptions} > "${outPath}" 2> "${errPath}"

        # Copy any artifacts into the output directory.
        cp -r inferred-predicates "${outDir}/"
        cp *.data "${outDir}/"
        cp *.psl "${outDir}/"
    popd > /dev/null
}

function run_split() {
    local splitName=$1

    local cliDir="${THIS_DIR}/../cli"
    local rulesPath="${cliDir}/mnist-sequence.psl"

    # Pick out the initial split used by the .data files so we can reset it later.
    local initialSplit=$(grep "data/mnist-sequence" "${cliDir}/mnist-sequence"*.data | sed 's#^.*/data/mnist-sequence/\([0-9_]\+\)/.*$#\1#' | head -n 1)

    # Change the split.
    sed -i "s#data/mnist-sequence/\([0-9_]\+\)/#data/mnist-sequence/${splitName}/#" "${cliDir}/mnist-sequence"*.data

    for batch in ${BATCH_SIZES}; do
        for learningRate in ${LEARNING_RATES}; do
            for epoch in ${EPOCHS}; do
                for computePeriod in ${COMPUTE_PERIODS}; do
                    for ruleSet in ${RULE_SETS}; do
                        for admmIterations in ${ADMM_ITERATIONS}; do
                            for binRankLower in ${BIN_RANK_LOWER}; do
                                for binRankUpper in ${BIN_RANK_UPPER}; do
                                    for binThresholdLower in ${BIN_THRESHOLD_LOWER}; do
                                        for binThresholdUpper in ${BIN_THRESHOLD_UPPER}; do
                                            local outDir="${BASE_OUT_DIR}/${batch}::Batch_Size/${learningRate}::Learning_Rate/${epoch}::Epochs/${computePeriod}::Compute_Period/${ruleSet}::Rule_Set/${admmIterations}::ADMM_Iterations/${binRankLower}::Bin_Rank_Lower/${binRankUpper}::Bin_Rank_Upper/${binThresholdLower}::Bin_Threshold_Lower/${binThresholdUpper}::Bin_Threshold_Upper"

                                            local options="${ADDITIONAL_PSL_OPTIONS}"
                                            options="${options} -D modelpredicate.batchsize=${batch}"
                                            options="${options} -D neural.learningrate=${learningRate}"
                                            options="${options} -D modelpredicate.iterations=${epoch}"
                                            options="${options} -D admmreasoner.computeperiod=${computePeriod}"
                                            options="${options} -D admmreasoner.maxiterations=${admmIterations}"
                                            options="${options} -D neural.binarize.rank.lower=${binRankLower}"
                                            options="${options} -D neural.binarize.rank.upper=${binRankUpper}"
                                            options="${options} -D neural.binarize.threshold.lower=${binThresholdLower}"
                                            options="${options} -D neural.binarize.threshold.upper=${binThresholdUpper}"

                                            if [ "${ruleSet}" == "single" ]; then
                                                sed -i 's/^[0-9].* -> PredictedNumber(Image[12], [XY]).*$/### \0/' "${rulesPath}"
                                            elif [ "${ruleSet}" == "triple" ]; then
                                                sed -i 's/^### //' "${rulesPath}"
                                            else
                                                echo "Unknown rule set: '${ruleSet}'."
                                                exit 1
                                            fi

                                            echo "Running: [Batch Size: ${batch}, Learning Rate: ${learningRate}, Epochs: ${epoch}, Compute Period: ${computePeriod}, Rule Set: ${ruleSet}, ADMM Iterations: ${admmIterations}, Bin Rank Lower: ${binRankLower}, Bin Rank Upper: ${binRankUpper}, Bin Threshold Lower: ${binThresholdLower}, Bin Threshold Upper: ${binThresholdUpper}]"

                                            run_psl "${cliDir}" "${outDir}" "${options}"
                                        done
                                    done
                                done
                            done
                        done
                    done
                done
            done
        done
    done

    # Reset the PSL file to no comments.
    sed -i 's/^### //' "${rulesPath}"

    # Reset the data files back to the initial split.
    sed -i "s#data/mnist-sequence/[0-9_]\\+#data/mnist-sequence/${initialSplit}#g" "${cliDir}/mnist-sequence"*.data
}

function main() {
    if [[ $# -eq 0 ]]; then
        echo "USAGE: $0 <split dir> ..."
        exit 1
    fi

    trap exit SIGINT

    for splitDir in "$@"; do
        run_split $(basename "${splitDir}")
    done
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
