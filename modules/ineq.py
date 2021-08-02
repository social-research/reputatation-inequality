"""
Created on Aug 2 2021
@author: milenavt
Purpose: Helping functions for correlation analysis
"""

import numpy as np
import pandas as pd
from scipy.stats import mannwhitneyu
import statsmodels.api as sm
import statsmodels.formula.api as smf
from sklearn import preprocessing


def coefvar(array):
    """Calculate coefficient of variation: variance/mean"""

    return np.var(array) / np.mean(array)


def mu_test(data, reverse=False):
    """Mann Whitney U test for plots"""

    res = []
    if reverse:
        for i in data[:-1]:
            x = mannwhitneyu(i, data[-1])
            res.append([x.statistic, x.pvalue])
    else:
        for i in data[1:]:
            x = mannwhitneyu(data[0], i)
            res.append([x.statistic, x.pvalue])
    return res


def correlation_model_nonstd(x, y, g, cluster, nonlinear, var1, var2):
    """OLS y = x with clustered standard errors by g (if cluster=True).
    If nonlinear=True, y = x + x^2.
    """
    df = pd.DataFrame({var1: pd.Series(x), var2: pd.Series(y), 'Group': pd.Series(g)})
    df = df.sort_values(var1)

    if cluster:
        if nonlinear:
            res = smf.ols(var2+' ~ '+var1+' + np.square('+var1+')', data=df).fit(cov_type='cluster',
                  cov_kwds={'groups': df['Group']}, use_t=True)
        else:
            res = smf.ols(var2+' ~ '+var1, data=df).fit(cov_type='cluster',
                  cov_kwds={'groups': df['Group']}, use_t=True)
    else:
        if nonlinear:
            res = smf.ols(var2+' ~ '+var1+' + np.square('+var1+')', data=df).fit()
        else:
            res = smf.ols(var2+' ~ '+var1, data=df).fit()
    return res


def correlation_model(x0, y0, g, cluster, nonlinear, var1, var2):
    """OLS y = x with clustered standard errors by g (if cluster=True),
    where y and x are standardized. The result is equivalent to
    the Pearson correlation coefficient.
    If nonlinear=True, y = x + x^2.
    """

    x = preprocessing.scale(x0)
    y = preprocessing.scale(y0)
    df = pd.DataFrame({var1: pd.Series(x), var2: pd.Series(y), 'Group': pd.Series(g)})
    df = df.sort_values(var1)

    if cluster:
        if nonlinear:
            res = smf.ols(var2+' ~ '+var1+' + np.square('+var1+')', data=df).fit(cov_type='cluster',
                  cov_kwds={'groups': df['Group']}, use_t=True)
        else:
            res = smf.ols(var2+' ~ '+var1, data=df).fit(cov_type='cluster',
                  cov_kwds={'groups': df['Group']}, use_t=True)
    else:
        if nonlinear:
            res = smf.ols(var2+' ~ '+var1+' + np.square('+var1+')', data=df).fit()
        else:
            res = smf.ols(var2+' ~ '+var1, data=df).fit()
    return res
