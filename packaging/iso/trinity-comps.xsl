<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:template match="/" name="identity">
        <xsl:copy-of select="comps/group/id[text()='core']/.."/>
        <xsl:copy-of select="comps/group/id[text()='base']/.."/>
        <xsl:copy-of select="comps/group/id[text()='debugging']/.."/>
        <xsl:copy-of select="comps/group/id[text()='development']/.."/>
        <xsl:copy-of select="comps/group/id[text()='hardware-monitoring']/.."/>
        <xsl:copy-of select="comps/group/id[text()='network-tools']/.."/>
        <xsl:copy-of select="comps/group/id[text()='performance']/.."/>
        <xsl:copy-of select="comps/group/id[text()='system-admin-tools']/.."/>
        <xsl:copy-of select="comps/group/id[text()='system-management']/.."/>
        <xsl:copy-of select="comps/environment/id[text()='minimal']/.."/>
        <xsl:copy-of select="comps/group/id[text()='trinityx']/.."/>
        <xsl:copy-of select="comps/environment/id[text()='trinityx']/.."/>
    </xsl:template>
    <xsl:template match="/">
        <xsl:call-template name="identity" />
    </xsl:template>
</xsl:stylesheet>
