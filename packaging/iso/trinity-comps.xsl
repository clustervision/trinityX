<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output method="xml" indent="yes"/>
    <xsl:template match="@*|node()" name="identity">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" />
        </xsl:copy>
    </xsl:template>
    <xsl:template match="comps/*[1]">
        <group>
            <id>trinity</id>
            <name>TriniyX</name>
            <description>All TrinityX packages will be installed</description>
            <default>false</default>
            <uservisible>false</uservisible>
            <packagelist>
              <packagereq type="mandatory">trinityx</packagereq>
              <packagereq type="mandatory">luna-ansible</packagereq>
              <packagereq type="mandatory">userspace-repo-tr17.10</packagereq>
            </packagelist>
        </group>
        <environment>
            <id>TrinityX</id>
            <name>TrinityX</name>
            <description>Basic packages and TriniyX</description>
            <display_order>3</display_order>
            <grouplist>
              <groupid>core</groupid>
              <groupid>base</groupid>
              <groupid>trinity</groupid>
            </grouplist>
            <optionlist>
              <groupid>debugging</groupid>
              <groupid>development</groupid>
              <groupid>hardware-monitoring</groupid>
              <groupid>network-tools</groupid>
              <groupid>performance</groupid>
              <groupid>system-admin-tools</groupid>
              <groupid>system-management</groupid>
            </optionlist>
        </environment>
        <xsl:call-template name="identity" />
    </xsl:template>
</xsl:stylesheet>
