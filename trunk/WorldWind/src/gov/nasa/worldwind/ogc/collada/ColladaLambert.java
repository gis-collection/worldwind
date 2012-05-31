/*
 * Copyright (C) 2012 United States Government as represented by the Administrator of the
 * National Aeronautics and Space Administration.
 * All Rights Reserved.
 */

package gov.nasa.worldwind.ogc.collada;

/**
 * @author pabercrombie
 * @version $Id$
 */
public class ColladaLambert extends ColladaAbstractShader
{
    /**
     * Construct an instance.
     *
     * @param namespaceURI the qualifying namespace URI. May be null to indicate no namespace qualification.
     */
    public ColladaLambert(String namespaceURI)
    {
        super(namespaceURI);
    }
}
