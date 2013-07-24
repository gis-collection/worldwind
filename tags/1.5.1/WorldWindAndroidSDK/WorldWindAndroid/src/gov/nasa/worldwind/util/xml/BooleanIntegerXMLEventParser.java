/*
 * Copyright (C) 2012 DreamHammer.com
 */

package gov.nasa.worldwind.util.xml;

import gov.nasa.worldwind.util.WWUtil;

/**
 * @author tag
 * @version $Id$
 */
public class BooleanIntegerXMLEventParser extends AbstractXMLEventParser
{
    public BooleanIntegerXMLEventParser()
    {
    }

    public BooleanIntegerXMLEventParser(String namespaceUri)
    {
        super(namespaceUri);
    }

    public Object parse(XMLEventParserContext ctx, XMLEvent booleanEvent, Object... args)
        throws XMLParserException
    {
        String s = this.parseCharacterContent(ctx, booleanEvent);
        if (s == null)
            return false;

        s = s.trim();

        if (s.length() > 1)
            return s.equalsIgnoreCase("true");

        return WWUtil.convertNumericStringToBoolean(s);
    }
}
