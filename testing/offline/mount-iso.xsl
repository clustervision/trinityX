<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="disk[@device='cdrom']">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()[not(self::source) and not(self::backingStore) and not(self::alias)]"/>
            <source file="{$iso}"/>
            <backingStore/>
            <alias name='ide0-0-0'/>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
