/*
 * Copyright (C) 2012 DreamHammer.com
 */

package gov.nasa.worldwind.kml;

import gov.nasa.worldwind.event.*;
import gov.nasa.worldwind.util.Logging;
import gov.nasa.worldwind.util.xml.*;

import java.util.Map;

/**
 * The abstract base class for most KML classes. Provides parsing and access to the <i>id</i> and <i>targetId</i> fields
 * of KML elements.
 *
 * @author tag
 * @version $Id$
 */
public class KMLAbstractObject extends AbstractXMLEventParser implements MessageListener
{
    public static final String MSG_BOX_CHANGED = "KMLAbstractObject.BoxChanged";
    public static final String MSG_GEOMETRY_CHANGED = "KMLAbstractObject.GeometryChanged";
    public static final String MSG_LINK_CHANGED = "KMLAbstractObject.LinkChanged";
    public static final String MSG_STYLE_CHANGED = "KMLAbstractObject.StyleChanged";
    public static final String MSG_TIME_CHANGED = "KMLAbstractObject.TimeChanged";
    public static final String MSG_VIEW_CHANGED = "KMLAbstractObject.ViewChanged";

    protected KMLAbstractObject()
    {
        super();
    }

    /**
     * Construct an instance.
     *
     * @param namespaceURI the qualifying namespace URI. May be null to indicate no namespace qualification.
     */
    protected KMLAbstractObject(String namespaceURI)
    {
        super(namespaceURI);
    }

    /**
     * Returns the id of this object, if any.
     *
     * @return the id of this object, or null if it's not specified in the element.
     */
    public String getId()
    {
        return (String) this.getField("id");
    }

    /**
     * Returns the target-id of this object, if any.
     *
     * @return the targetId of this object, or null if it's not specified in the element.
     */
    public String getTargetId()
    {
        return (String) this.getField("targetId");
    }

    @Override
    public KMLRoot getRoot()
    {
        XMLEventParser root = super.getRoot();
        return root instanceof KMLRoot ? (KMLRoot) root : null;
    }

    public void onMessage(Message msg)
    {
        // Empty implementation
    }

    public void onChange(Message msg)
    {
        if (this.getParent() != null)
            ((KMLAbstractObject) this.getParent()).onChange(msg);
    }

    public void applyChange(KMLAbstractObject sourceValues)
    {
        if (sourceValues == null)
        {
            String message = Logging.getMessage("nullValue.SourceIsNull");
            Logging.warning(message);
            throw new IllegalArgumentException(message);
        }

        for (Map.Entry<String, Object> entry : sourceValues.getFields().getEntries())
        {
            this.setField(entry.getKey(), entry.getValue());
        }
    }
}
