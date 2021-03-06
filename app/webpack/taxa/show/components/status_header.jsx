import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";

const StatusHeader = ( { status } ) => {
  let text = status.statusText( );
  text = I18n.t( text, { defaultValue: text } );
  let alertClass;
  switch ( status.iucnStatusCode( ) ) {
    case "LC":
      alertClass = "iucn-least-concern";
      break;
    case "NT":
    case "VU":
      alertClass = "iucn-vulnerable";
      break;
    case "CR":
    case "EN":
      alertClass = "iucn-endangered";
      break;
    case "EW":
    case "EX":
      alertClass = "iucn-extinct";
      break;
    default:
      // ok
  }
  return (
    <div className={`alert ${alertClass} StatusHeader`}>
      <i className="glyphicon glyphicon-flag" />
      { " " }
      <strong>
        {
          status.place
            ? I18n.t( "status_in_place", { status: I18n.t( text, { defaultValue: text } ), place: status.place.display_name } )
            : I18n.t( "status_globally", { status: I18n.t( text, { defaultValue: text } ) } )
        }
      </strong>
      { " " }
      { I18n.t( "label_colon", { label: I18n.t( "source" ) } ) }
      { " " }
      <a href={status.url}>{ status.authority }</a>
    </div>
  );
};

StatusHeader.propTypes = {
  status: PropTypes.object
};

export default StatusHeader;
