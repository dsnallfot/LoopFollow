"""Load production status parsing/mapping with a lightweight UIColor stand-in on macOS."""
def status_source(repo):
    source = (repo / 'LoopFollow/InfoTable/InfoData.swift').read_text()
    source = source[source.index('enum InfoStatusSymbol:'):]
    return '''import Foundation
    enum UIColor { case systemRed, systemYellow, systemGreen, systemPurple, systemOrange,
        systemBlue, lightGray, secondaryLabel }
    ''' + source
