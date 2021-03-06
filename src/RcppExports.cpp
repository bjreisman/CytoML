// Generated by using Rcpp::compileAttributes() -> do not edit by hand
// Generator token: 10BE3573-1514-4C36-9D1C-5A225CD40393

#include "../inst/include/CytoML.h"
#include <Rcpp.h>

using namespace Rcpp;

// parseWorkspace
XPtr<GatingSet> parseWorkspace(string fileName, vector<string> sampleIDs, vector<string> sampleNames, bool isParseGate, unsigned short sampNloc, int xmlParserOption, unsigned short wsType);
RcppExport SEXP _CytoML_parseWorkspace(SEXP fileNameSEXP, SEXP sampleIDsSEXP, SEXP sampleNamesSEXP, SEXP isParseGateSEXP, SEXP sampNlocSEXP, SEXP xmlParserOptionSEXP, SEXP wsTypeSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< string >::type fileName(fileNameSEXP);
    Rcpp::traits::input_parameter< vector<string> >::type sampleIDs(sampleIDsSEXP);
    Rcpp::traits::input_parameter< vector<string> >::type sampleNames(sampleNamesSEXP);
    Rcpp::traits::input_parameter< bool >::type isParseGate(isParseGateSEXP);
    Rcpp::traits::input_parameter< unsigned short >::type sampNloc(sampNlocSEXP);
    Rcpp::traits::input_parameter< int >::type xmlParserOption(xmlParserOptionSEXP);
    Rcpp::traits::input_parameter< unsigned short >::type wsType(wsTypeSEXP);
    rcpp_result_gen = Rcpp::wrap(parseWorkspace(fileName, sampleIDs, sampleNames, isParseGate, sampNloc, xmlParserOption, wsType));
    return rcpp_result_gen;
END_RCPP
}

static const R_CallMethodDef CallEntries[] = {
    {"_CytoML_parseWorkspace", (DL_FUNC) &_CytoML_parseWorkspace, 7},
    {NULL, NULL, 0}
};

RcppExport void R_init_CytoML(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
