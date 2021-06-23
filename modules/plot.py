import numpy as np
import pandas as pd
import seaborn as sb
import matplotlib as mpl
import matplotlib.pyplot as plt
from ineq import *

BOXPROPS = {'linewidth': 0.25}
FLIERPROPS = {'linewidth': 0.25, 'marker': '.', 'markersize': 1, 'markeredgecolor': 'k', 'markerfacecolor': 'k'}
MEDIANPROPS = {'linewidth': 0.35, 'color': 'k'}
WHISKERPROPS = {'linewidth': 0.25}
CAPPROPS = {'linewidth': 0.25}

def init_plot():
    sb.set_style('ticks')
    mpl.rcParams['font.size'] = 6
    mpl.rcParams['xtick.labelsize'] = 6
    mpl.rcParams['ytick.labelsize'] = 6
    mpl.rcParams['legend.fontsize'] = 6
    mpl.rcParams['axes.linewidth'] = 0.25
    mpl.rcParams['xtick.major.size'] = 2
    mpl.rcParams['ytick.major.width'] = 0.25
    mpl.rcParams['ytick.major.size'] = 2
    mpl.rcParams['xtick.major.width'] = 0.25
    mpl.rcParams['xtick.major.pad']='4'
    mpl.rcParams['ytick.major.pad']='4'
    mpl.rcParams['xtick.minor.size'] = 2
    mpl.rcParams['ytick.minor.width'] = 0.25
    mpl.rcParams['ytick.minor.size'] = 2
    mpl.rcParams['xtick.minor.width'] = 0.25
    mpl.rcParams['lines.linewidth'] = 0.25
    mpl.rcParams['patch.linewidth'] = 0.25
    mpl.rcParams['lines.markersize'] = 3
    mpl.rcParams['font.family'] = 'sans-serif'
    mpl.rcParams['font.sans-serif'] = ['Arial']


def custom_boxplot(ax, y, positions, colors):
    bp = ax.boxplot(y, positions=positions, widths=0.15, patch_artist=True, sym='.',
              boxprops=BOXPROPS, flierprops=FLIERPROPS, capprops=CAPPROPS,
              medianprops=MEDIANPROPS, whiskerprops=WHISKERPROPS)
    for patch, color in zip(bp['boxes'], colors):
        patch.set_facecolor(color)


def custom_annotate(txt, coord):
    plt.annotate(txt, xy=coord,
                xycoords='figure fraction',
                horizontalalignment='left', verticalalignment='top',
                fontsize=8, fontweight='bold')


def get_text_for_test(test, precision = 3, preceding0=True):
    if preceding0:
        txt = ("{0:."+str(precision)+"f}").format(round(test[0], precision)) + \
               '\n' + "{0:.2f}".format(round(test[1], 2))
    else:
        txt = ("{0:."+str(precision)+"f}").format(round(test[0], precision)) + \
               '\n' + "{0:.2f}".format(round(test[1], 2)).lstrip('0')
    if test[1] < 0.05:
        txt = txt+'*'
    return txt


def get_text_for_test2(test):
    txt = "{0:.3f}".format(round(test[0],3))+' ('+"{0:.2f}".format(round(test[1],2))
    if test[1] < 0.05:
        txt = txt+'*'
    txt = txt+')'
    return txt


def clear_axis(ax, axtype):
    if axtype == 'x':
        ax.set_xticks([])
        ax.set_xticklabels([])
    else:
        ax.set_yticks([])
        ax.set_yticklabels([])


def plot_fit(ax, x0, y0, var1, var2, xloc, yloc):
    x = [j for i in x0 for j in x0[i] if ~np.isnan(j)]
    y = [j for i in x0 for j in y0[i] if ~np.isnan(j)]
    g = [i for i in x0 for j in x0[i] if ~np.isnan(j)]

    # Fit lines on plot separately for each group
    for gi in x0:
        res = correlation_model_nonstd([i for i in x0[gi] if ~np.isnan(i)], \
                                       [i for i in y0[gi] if ~np.isnan(i)], \
                                       [gi], cluster=False, nonlinear=False, var1=var1, var2=var2)
        ax.plot(sorted([i for i in x0[gi] if ~np.isnan(i)]), res.fittedvalues, 'k-',lw=0.5)

    # Do not cluster if it is only one group
    cluster = True
    if len(set(g))==1:
        cluster=False
    res = correlation_model(x, y, g, cluster, nonlinear=False, var1=var1, var2=var2)
    ax.text(xloc, yloc, get_text_for_test([res.params[1], res.pvalues[1]], precision=3), \
            fontsize=6, horizontalalignment='right', transform=ax.transAxes)


def plot_fit_quad(ax, x0, y0, var1, var2, xloc, yloc):
    x = [j for i in x0 for j in x0[i] if ~np.isnan(j)]
    y = [j for i in x0 for j in y0[i] if ~np.isnan(j)]
    g = [i for i in x0 for j in x0[i] if ~np.isnan(j)]

    # Fit lines on plot separately for each group
    for gi in x0:
        res = correlation_model_nonstd([i for i in x0[gi] if ~np.isnan(i)], \
                                       [i for i in y0[gi] if ~np.isnan(i)], \
                                       [gi], cluster=False, nonlinear=True, var1=var1, var2=var2)
        ax.plot(sorted([i for i in x0[gi] if ~np.isnan(i)]), res.fittedvalues, 'k-',lw=0.5)

    # Do not cluster if it is only one group
    cluster = True
    if len(set(g))==1:
        cluster=False
    res = correlation_model(x, y, g, cluster, nonlinear=True, var1=var1, var2=var2)
    ax.text(xloc, yloc, get_text_for_test2([res.params[1], res.pvalues[1]]),
            fontsize=6, horizontalalignment='right', transform=ax.transAxes)
    ax.text(xloc, yloc-0.12, get_text_for_test2([res.params[2], res.pvalues[2]]),
            fontsize=6, horizontalalignment='right', transform=ax.transAxes)
