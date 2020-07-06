#!/bin/bash

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_OUT_DIR="${THIS_DIR}/../results"

readonly HEADER="Batch Size\tLearning Rate\tEpochs\tCompute Period\tRule Set\tADMM Iterations\tBin Rank Lower\tBin Rank Upper\tBin Threshold Lower\tBin Threshold Upper\tCategorical Accuracy"
readonly PATTERN='s#^.*/([\d\.]+)::Batch_Size/([\d\.]+)::Learning_Rate/([\d\.]+)::Epochs/([\d\.]+)::Compute_Period/(single|triple)::Rule_Set/([\d\.]+)::ADMM_Iterations/([\d\.]+)::Bin_Rank_Lower/([\d\.]+)::Bin_Rank_Upper/([\d\.]+)::Bin_Threshold_Lower/([\d\.]+)::Bin_Threshold_Upper/.*Categorical Accuracy: ([\d\.]+).*$#$1\t$2\t$3\t$4\t$5\t$6\t$7\t$8\t$9\t$10\t$11#'

function main() {
    if [[ ! $# -eq 0 ]]; then
        echo "USAGE: $0"
        exit 1
    fi

    trap exit SIGINT

    echo -e "${HEADER}"
    grep -R "Evaluation results for PREDICTEDNUMBER" "${BASE_OUT_DIR}" | perl -pe "$PATTERN"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
