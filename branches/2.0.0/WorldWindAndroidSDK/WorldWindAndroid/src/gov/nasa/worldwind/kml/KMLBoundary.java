/*
 * Copyright (C) 2012 DreamHammer.com
 */

package gov.nasa.worldwind.kml;

/**
 * Represents the KML <i>Boundary</i> style and provides access to its contents.
 *
 * @author tag
 * @version $Id$
 */
public class KMLBoundary extends KMLAbstractObject
{
    /**
     * Construct an instance.
     *
     * @param namespaceURI the qualifying namespace URI. May be null to indicate no namespace qualification.
     */
    public KMLBoundary(String namespaceURI)
    {
        super(namespaceURI);
    }

    public KMLLinearRing getLinearRing()
    {
        return (KMLLinearRing) this.getField("LinearRing");
    }
}
