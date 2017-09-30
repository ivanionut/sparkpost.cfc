component accessors="true" {

  property name="from" default="";
  property name="subject" default="";
  property name="personalizations";
  property name="content" default="";
  property name="reply_to" default="";
  property name="attachments" default="";
  property name="template_id" default="";
  property name="sections" default="";
  property name="headers" default="";
  property name="categories" default="";
  property name="custom_args" default="";
  property name="send_at" default="";
  property name="batch_id" default="";
  property name="asm" default="";
  property name="ip_pool_name" default="";
  property name="mail_settings" default="";
  property name="tracking_settings" default="";

  /**
  * @hint You don't need to init this with any variables, but it's an optional approach
  * @content The assumption, when this is passed in, is that it is HTML, and that both html and plain text should be set and sent. Don't use the shortcut to init if you only want plain text
  */
  public any function init( any from, string subject, any to, string content ) {

    setPersonalizations( [] );
    setContent( [] );
    setAttachments( [] );
    setHeaders( {} );
    setCategories( [] );
    setCustom_args( {} );

    if ( arguments.keyExists( 'from' ) )
      this.from( from );

    if ( arguments.keyExists( 'subject' ) )
      setSubject( subject );

    if ( arguments.keyExists( 'to' ) )
      this.to( to );

    if ( arguments.keyExists( 'content' ) )
      plainFromHtml( content );

    variables.utcBaseDate = dateAdd( "l", createDate( 1970,1,1 ).getTime() * -1, createDate( 1970,1,1 ) );

    return this;
  }

  public any function from( required any email ) {
    setFrom( parseEmail( email ) );
    return this;
  }

  public any function replyTo( required any email ) {
    setReply_to( parseEmail( email ) );
    return this;
  }

  /**
  * @hint Sets the global subject. This may be overridden by personalizations[x].subject.
  */
  public any function subject( required string subject ) {
    setSubject( subject );
    return this;
  }

  /**
  * @hint convenience method for adding the text/html content
  */
  public any function html( required string message ) {
    var htmlContent = {
        'type' : 'text/html',
        'value' : message
      };
    return emailContent( htmlContent );
  }

  /**
  * @hint convenience method for adding the text/plain content
  */
  public any function plain( required string message ) {
    var plainContent = {
        'type' : 'text/plain',
        'value' : message
      };
    return emailContent( plainContent, false );
  }

  /**
  * @hint method for setting any content mimetype. The default is that the new mimetype is appended, but you can override this
  */
  public any function emailContent( required struct content, boolean doAppend = true ) {
    if ( doAppend )
      variables[ 'content' ].append( content );
    else
      variables[ 'content' ].prepend( content );
    return this;
  }

  /**
  * @hint convenience method for setting both text/html and text/plain at the same time. You can either pass in the HTML content, and both will be set from it (using a method to strip the HTML for the plain text version), or you can call the method without an argument, after having set the HTML, and that will be used.
  */
  public any function plainFromHtml( string message = '' ) {

    var plainContent = getPlainContent(); //don't know if this is needed. Not sure how SendGrid would handle it if mimetype were set twice.
    if ( plainContent.len() ) throw( 'The text/plain content has already been set.' );

    if ( !message.len() ) {

      var htmlContent = getHtmlContent();

      if ( !htmlContent.len() ) throw( 'The text/html content needs to be set prior to calling #getFunctionCalledName()# without the html argument.' );

      plain( removeHTML( htmlContent ) );

    } else {
      plain( removeHTML( message ) );
      html( message );
    }

    return this;
  }

  /**
  * @hint Sets the `attachments` property for the global message. If any attachments were previously set, this method overwrites them.
  */
  public any function attachments( required array attachments ) {
    setAttachments( attachments );
    return this;
  }

  /**
  * @hint Appends a single attachment to the message.
  * @attachment A struct with at minimum keys for `content` and `filename`. View the SendGrid docs for the full makeup of the object: https://sendgrid.api-docs.io/v3.0/mail-send
  */
  public any function addAttachment( required struct attachment ) {
    variables.attachments.append( attachment );

    return this;
  }

  /**
  * @hint a convenience method for appending a single file attachment to the message
  * @filePath The relative or absolute path to an on-disk file. Its properties are used if the additional arguments aren't provided
  */
  public any function attachFile( required string filePath, string fileName, string type, string disposition = 'attachment', string content_id ) {

    var fullPath = expandPath( filePath );

    var binaryFile = fileReadBinary( fullPath );
    var encodedFile = binaryEncode( binaryFile, 'Base64' );

    var attachment = {
      'content': encodedFile,
      'filename': fileName ?: getFileFromPath( fullPath ),
      'type' : type ?: FileGetMimeType( fullPath ),
      'disposition': disposition
    };

    if ( !isNull( content_id ) ) attachment[ 'content_id' ] = content_id;

    addAttachment( attachment );

    return this;
  }

  /**
  * https://sendgrid.com/docs/User_Guide/Transactional_Templates/index.html
  * @hint Sets the id of a template that you would like to use for the message
  */
  public any function templateId( required string templateId ) {
    setTemplate_id( templateId );
    return this;
  }

  /**
  * https://sendgrid.com/docs/API_Reference/SMTP_API/section_tags.html (from SMTP API, but helpful for understanding use)
  * https://sendgrid.com/docs/Classroom/Build/Add_Content/substitution_and_section_tags.html
  * @hint Appends a single section block to the global message's `sections` property.
  * @section Facilitates two means of adding a section. You can pass in a struct with a key/value pair for the section tag and code block to replace it with. Alternatively, you can use this to pass in the section tag, and provide the replacement value as a second argument.
  */
  public any function section( required any section, any value ) {
    if ( isStruct( section ) )
      variables.sections.append( section );
    else
      variables.sections[ section ] = value;

    return this;
  }

  /**
  * @hint Sets the `sections` property for the global message. If any sections were previously set, this method overwrites them.
  * @sections An object containing key/value pairs of section tags and their replacement values.
  */
  public any function sections( required struct sections ) {
    setSections( sections );
    return this;
  }

  /**
  * @hint Appends a single header to the global message's `headers` property. This can be overridden by a personalized header.
  * @header Facilitates two means of setting a header. You can pass in a struct with a key/value pair for the name and value of the header. Alternatively, you can use this to pass in the name of the header, and provide the value as a second argument.
  */
  public any function header( required any header, any value ) {
    if ( isStruct( header ) )
      variables.headers.append( header );
    else
      variables.headers[ header ] = value;

    return this;
  }

  /**
  * @hint Sets the `headers` property for the global message. Headers can be overridden by a personalized header. If any headers were previously set, this method overwrites them.
  * @headers An object containing key/value pairs of header names and their value. You must ensure these are properly encoded if they contain unicode characters. Must not be any of the following reserved headers: x-sg-id, x-sg-eid, received, dkim-signature, Content-Type, Content-Transfer-Encoding, To, From, Subject, Reply-To, CC, BCC
  */
  public any function headers( required struct headers ) {
    setHeaders( headers );
    return this;
  }

  /**
  * @hint Sets the category array for the global message. If categories are already set, this overwrites them.
  * @categories Can be passed in as an array or comma separated list. Lists will be converted to arrays
  */
  public any function categories( required any categories ) {
    if ( isArray( categories ) )
      setCategories( categories );
    else
      setCategories( categories.listToArray() );

    return this;
  }

  /**
  * @hint Appends a single category to the global message category array
  */
  public any function addCategory( required string category ) {
    variables.categories.append( category );

    return this;
  }

  /**
  * @hint Appends a single custom argument on the global message's `custom_args` property. This can be overridden by a personalized custom argument.
  * @arg Facilitates two means of setting a custom argument. You can pass in a struct with a key/value pair, for example, { "Team": "Engineering" }, or you can use this to pass in the custom argument's name, and provide the value as a second argument.
  */
  public any function customArg( required any arg, any value ) {
    if ( isStruct( arg ) )
      variables.custom_args.append( header );
    else
      variables.custom_args[ arg ] = value;

    return this;
  }

  /**
  * @hint Sets the `custom_args` property for the global message. Custom arguments can be overridden by a personalized custom argument. If any custom arguments were previously set, this overwrites them.
  * @args An object containing the key/value pairs of parameter names and their values. For example, { "Team": "Engineering", "Color": "Gray" }
  */
  public any function customArgs( required struct args ) {
    setCustom_args( args );
    return this;
  }

  /**
  * @hint Sets the global `send_at` property, which specifies when you want the email delivered. This may be overridden by the personalizations[x].send_at.
  */
  public any function sendAt( required date timeStamp ) {
    setSend_at( getUTCTimestamp( timeStamp ) );

    return this;
  }

  /**
  * @hint Sets the global `batch_id` property, which represents a group of emails that are associated with each other. The sending of emails in a batch can be cancelled or paused. Note that you must generate the batchID value via the API.
  */
  public any function batchId( required string batchId ) {
    setBatch_id( batchId );
    return this;
  }

  /**
  * @hint Adds a NEW personalization envelope, with only the specified email address. The personalization can then be further customized with later commands
  */
  public any function to( required any email ) {
    addPersonalization(
      {
        'to': [ parseEmail( email ) ]
      }
    );
    return this;
  }

  /**
  * @hint Adds an additional 'to' recipient to the **current** personalization envelope
  */
  public any function addTo( required any email ) {
    var count = countPersonalizations();

    if ( count ) {
      variables.personalizations[ count ][ 'to' ].append( parseEmail( email ) );

      return this;
    } else {
      return to( email );
    }
  }

  /**
  * @hint Adds an additional 'cc' recipient to the **current** personalization envelope
  */
  public any function addCC( required any email ) {
    return addCarbonCopies( email, 'cc' );
  }

  /**
  * @hint Adds an additional 'bcc' recipient to the **current** personalization envelope
  */
  public any function addBCC( required any email ) {
    return addCarbonCopies( email, 'bcc' );
  }

  /**
  * @hint Sets the subject for the **current** personalization envelope. This overrides the global email subject for these recipients. A basic personalization envelope (with a 'to' recipient) needs to be in place before this can be added.
  */
  public any function withSubject( required string subject ) {
    var count = countPersonalizations();

    //not sure to what extent I should validate
    //if ( !count ) throw( "The email needs to be sent 'to' someone before it can be personalized.");

    variables.personalizations[ count ][ 'subject' ] = subject;

    return this;
  }

  /**
  * @hint functions like `header()`, except it adds the header to the **current** personalization envelope. You can set a header by providing the header and value, or by passing in a struct.
  * @header Facilitates two means of setting a header. You can pass in a struct with a key/value pair for the name and value of the header. Alternatively, you can use this to pass in the name of the header, and provide the value as a second argument.
  */
  public any function withHeader( any header, any value ) {
    var count = countPersonalizations();
    if ( !count ) throw( "You must add a 'to' recipient to this email before you can personalize headers" );

    if ( !variables.personalizations[ count ].keyExists( 'headers' ) )
      variables.personalizations[ count ][ 'headers' ] = {};

    if ( isStruct( header ) )
      variables.personalizations[ count ][ 'headers' ].append( header );
    else
      variables.personalizations[ count ][ 'headers' ][ header ] = value;

    return this;
  }

  /**
  * @hint functions like `headers()`, except it sets the `headers` property for the **current** personalization envelope. If any personalized headers were previously set, this method overwrites them.
  */
  public any function withHeaders( required struct headers ) {
    var count = countPersonalizations();
    if ( !count ) throw( "You must add a 'to' recipient to this email before you can personalize headers" );

    variables.personalizations[ count ][ 'headers' ] = headers;

    return this;
  }

  /**
  * @hint appends a substitution ( "substitution_tag":"value to substitute" ) to the **current** personalization envelope. You can add a substitution by providing the tag and value to substitute, or by passing in a struct.
  * @substitution Facilitates two means of adding a substitution. You can pass in a struct with a tag/value for the substitution tag and value to substitute. Alternatively, you can use this argument to pass in the substitution tag, and provide the replacement value as a second argument.
  */
  public any function withSubstitution( any substitution, any value ) {
    var count = countPersonalizations();
    if ( !count ) throw( "You must add a 'to' recipient to this email before you can personalize substitutions" );

    if ( !variables.personalizations[ count ].keyExists( 'substitutions' ) )
      variables.personalizations[ count ][ 'substitutions' ] = {};

    if ( isStruct( substitution ) )
      variables.personalizations[ count ][ 'substitutions' ].append( substitution );
    else
      variables.personalizations[ count ][ 'substitutions' ][ substitution ] = value;

    return this;
  }

  /**
  * @hint sets the `substitutions` property for the **current** personalization envelope. If any substitutions were previously set, this method overwrites them.
  * @substitutions An object containing key/value pairs of substitution tags and their replacement values.
  */
  public any function withSubstitutions( required struct substitutions ) {
    var count = countPersonalizations();
    if ( !count ) throw( "You must add a 'to' recipient to this email before you can personalize substitutions." );

    variables.personalizations[ count ][ 'substitutions' ] = substitutions;

    return this;
  }

  /**
  * @hint functions like `customArg()`, except it adds the custom argument to the **current** personalization envelope.
  * @arg Facilitates two means of setting a custom argument. You can pass in a struct with a key/value pair, for example, { "Team": "Engineering" }, or you can use this to pass in the custom argument's name, and provide the value as a second argument.
  */
  public any function withCustomArg( required any arg, any value ) {
    var count = countPersonalizations();
    if ( !count ) throw( "You must add a 'to' recipient to this email before you can personalize custom arguments." );

    if ( !variables.personalizations[ count ].keyExists( 'custom_args' ) )
      variables.personalizations[ count ][ 'custom_args' ] = {};

    if ( isStruct( arg ) )
      variables.personalizations[ count ][ 'custom_args' ].append( arg );
    else
      variables.personalizations[ count ][ 'custom_args' ][ arg ] = value;

    return this;
  }

  /**
  * @hint functions like `customArgs()`, except it sets the `custom_args` property for the **current** personalization envelope. If any personalized custom arguments were previously set, this method overwrites them.
  */
  public any function withCustomArgs( required struct args ) {
    var count = countPersonalizations();
    if ( !count ) throw( "You must add a 'to' recipient to this email before you can personalize custom arguments." );

    variables.personalizations[ count ][ 'custom_args' ] = args;

    return this;
  }

  /**
  * @hint functions like `sendAt()`, except it sets the desired send time for the **current** personalization envelope.
  */
  public any function withSendAt( required date timeStamp ) {
    var count = countPersonalizations();
    if ( !count ) throw( "You must add a 'to' recipient to this email before you can personalize when it is sent." );

    variables.personalizations[ count ][ 'send_at' ] = getUTCTimestamp( timeStamp );

    return this;
  }

  /**
  * @hint Creates and sets a new personalization envelope
  * Documentation about personalizations here: https://sendgrid.com/docs/Classroom/Send/v3_Mail_Send/personalizations.html
  * I find the easiest way to understand this is that each personalization object is an individual email. That it, all of its properties, even if there are multiple to/cc/bcc, refer to the same email. So if you're adding a second personalization object, you're basically referring to a separate email... except that the sender/content of the email is the same
  * Note: custom_args = internal tracking, while substitutions are for the content of the email/subject
  */
  public void function addPersonalization( required struct personalization ) {

    if ( !personalization.keyExists( 'to' ) ) throw( 'You must include at least one "to" object within the personalization object.' );

    variables.personalizations.append( personalization );
  }

  public string function build() {

    var body = '';
    var properties = getPropertyValues();
    var count = properties.len();

    properties.each(
      function( property, index ) {

        var serializeMethod = 'serialize#property.key#';
        var value = { 'data': property.value };
        body &= '"#property.key#": ' & invoke( this, serializeMethod, value ) & '#index NEQ count ? "," : ""#';
      }
    );

    return '{' & body & '}';
  }

  private numeric function countPersonalizations() {
    return getPersonalizations().len();
  }

  private string function getHtmlContent() {
    return getContentByMimeType( 'text/html' );
  }

  private string function getPlainContent() {
    return getContentByMimeType( 'text/plain' );
  }

  private string function getContentByMimeType( required string mimetype ) {
    var mimeTypeContent = variables[ 'content' ].reduce(
        function( result, item, index ) {

          if ( item.type == mimetype );
            result = item.value;

          return result;
        }, ''
      );
    return mimeTypeContent;
  }

  /**
  * @hint Adds an additional cc/bcc receipients to the CURRENT personalization envelope
  */
  private any function addCarbonCopies( required any email, required string type ) {
    var count = countPersonalizations();
    if ( !count ) throw( "You must add a 'to' recipient to this email before you can #type# additional recipients." );

    if ( !variables.personalizations[ count ].keyExists( type ) )
      variables.personalizations[ count ][ type ] = [];

    variables.personalizations[ count ][ type ].append( parseEmail( email ) );

    return this;
  }

  /**
  * @hint If a struct is received, it is assumed it's in the proper format. Strings are parsed to check for bracketed email format
  */
  private struct function parseEmail( any email ) {
    if ( isStruct( email ) ) {
      return email;
    } else {
      var regex = '<([^>]+)>';
      var bracketedEmails = email.reMatchNoCase( regex );
      if ( bracketedEmails.len() ) {
        var bracketedEmail = bracketedEmails[1];
        return {
          'email' : bracketedEmail.REReplace( '[<>]', '', 'all'),
          'name' : email.replacenocase( bracketedEmail, '' ).trim()
        };

      } else {
        return {
          'email' : email,
          'name' : ''
        };

      }
    }
  }

  /**
  * @hint needs to be public because it is called via invoke()
  */
  public string function serializeHeaders( required struct data ) {
    return serializeValuesAsString( data );
  }

  /**
  * @hint needs to be public because it is called via invoke()
  */
  public string function serializeCustom_args( required struct data ) {
    return serializeValuesAsString( data );
  }

  /**
  * @hint needs to be public because it is called via invoke()
  */
  public string function serializeCategories( required array data ) {
    var serializedData = data.reduce(
      function( result, item, index ) {
        if ( result.len() ) result &= ',';

        return result & '"#item#"';
      }, ''
    );

    return '[' & serializedData & ']';
  }

  /**
  * @hint needs to be public because it is called via invoke()
  */
  public string function serializePersonalizations( required array data ) {

    var serializedData = '';

    data.each(
      function( envelope, index ) {

        var serializedEnvelope = envelope.reduce(
          function( result, key, value ) {

            if ( result.len() ) result &= ',';

            if ( arrayContains( [ 'headers', 'substitutions', 'custom_args' ], key ) )
              return result & '"#key#": #serializeValuesAsString( value )#';
            else
              return result & '"#key#": #serializeJSON( value )#';
          }, ''
        );
        serializedData &= '{' & serializedEnvelope & '}';
      }
    );

    return '[' & serializedData & ']';
  }

  /**
  * @hint helper that forces object value serialization to strings. This is needed in some cases, where CF's loose typing causes problems
  */
  private string function serializeValuesAsString( required struct data ) {
    var serializedData = data.reduce(
      function( result, key, value ) {

        if ( result.len() ) result &= ',';

        return result & '"#key#": "#value#"';
      }, ''
    );
    return '{' & serializedData & '}';
  }

  private numeric function getUTCTimestamp( required date dateToConvert ) {
    return dateDiff( "s", variables.utcBaseDate, dateToConvert );
  }

  private date function parseUTCTimestamp( required numeric utcTimestamp ) {
    return dateAdd( "s", utcTimestamp, variables.utcBaseDate );
  }

  /** This could probably go in a separate utils CFC, but it's here for now
  * Removes All HTML from a string removing tags, script blocks, style blocks, and replacing special character code.
  *
  * @author Scott Bennett (scott@coldfusionguy.com)
  * @version 1, November 14, 2007
  */
  private string function removeHTML( required string source ){

    // Remove all spaces becuase browsers ignore them
    var result = ReReplace(trim(source), "[[:space:]]{2,}", " ","ALL");

    // Remove the header
    result = ReReplace(result, "<[[:space:]]*head.*?>.*?</head>","", "ALL");

    // remove all scripts
    result = ReReplace(result, "<[[:space:]]*script.*?>.*?</script>","", "ALL");

    // remove all styles
    result = ReReplace(result, "<[[:space:]]*style.*?>.*?</style>","", "ALL");

    // insert tabs in spaces of <td> tags
    result = ReReplace(result, "<[[:space:]]*td.*?>","  ", "ALL");

    // insert line breaks in places of <BR> and <LI> tags
    result = ReReplace(result, "<[[:space:]]*br[[:space:]]*>",chr(13), "ALL");
    result = ReReplace(result, "<[[:space:]]*li[[:space:]]*>",chr(13), "ALL");

    // insert line paragraphs (double line breaks) in place
    // if <P>, <DIV> and <TR> tags
    result = ReReplace(result, "<[[:space:]]*div.*?>",chr(13), "ALL");
    result = ReReplace(result, "<[[:space:]]*tr.*?>",chr(13), "ALL");
    result = ReReplace(result, "<[[:space:]]*p.*?>",chr(13), "ALL");

    // Remove remaining tags like <a>, links, images,
    // comments etc - anything thats enclosed inside < >
    result = ReReplace(result, "<.*?>","", "ALL");

    // replace special characters:
    result = ReReplace(result, "&nbsp;"," ", "ALL");
    result = ReReplace(result, "&bull;"," * ", "ALL");
    result = ReReplace(result, "&lsaquo;","<", "ALL");
    result = ReReplace(result, "&rsaquo;",">", "ALL");
    result = ReReplace(result, "&trade;","(tm)", "ALL");
    result = ReReplace(result, "&frasl;","/", "ALL");
    result = ReReplace(result, "&lt;","<", "ALL");
    result = ReReplace(result, "&gt;",">", "ALL");
    result = ReReplace(result, "&copy;","(c)", "ALL");
    result = ReReplace(result, "&reg;","(r)", "ALL");

    // Remove all others. More special character conversions
    // can be added above if needed
    result = ReReplace(result, "&(.{2,6});", "", "ALL");

    // Thats it.
    return result;

  }

  /**
  * @hint converts the array of properties to an array of their keys/values, while filtering those that have not been set
  */
  private array function getPropertyValues() {

    var propertyValues = getProperties().map(
      function( item, index ) {
        return {
          "key" : item.name,
          "value" : getPropertyValue( item.name )
        };
      }
    );

    return propertyValues.filter(
      function( item, index ) {
        if ( isStruct( item.value ) )
          return !item.value.isEmpty();
        else
          return item.value.len();
      }
    );
  }

  private array function getProperties() {

    var metaData = getMetaData( this );
    var properties = [];

    for( var prop in metaData.properties ) {
      properties.append( prop );
    }

    return properties;
  }

  private any function getPropertyValue( string key ){
    var method = this["get#key#"];
    var value = method();
    return value;
  }

  /**
  * @hint currently in place to provide a standard fallback when a custom serialization method isn't needed (i.e. most cases)
  */
  public any function onMissingMethod ( string missingMethodName, struct missingMethodArguments ) {
    var action = missingMethodName.left( 9 );
    var property = missingMethodName.right( missingMethodName.len() - 9 );

    if ( action == 'serialize' ) {

      if ( !missingMethodArguments.isEmpty() )
        return serializeJson( missingMethodArguments.data );
      else
        throw "#missingMethodName#() called without an argument";

    } else {
      var message = "no such method (" & missingMethodName & ") in " & getMetadata( this ).name & "; [" & structKeyList( this ) & "]";
      throw "#message#";
    }

  }

}
