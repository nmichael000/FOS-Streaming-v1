<?php
class Activity extends FosStreaming {

    protected $table = 'activity';

    public function user()
    {
        return $this->hasOne('User', 'id', 'user_id');
    }

    public function stream()
    {
        
        return $this->hasOne('Stream', 'id', 'stream_id');
    }
}
