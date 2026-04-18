import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type MeetingDocument = Meeting & Document;

export enum MeetingPlatform {
  ZOOM = 'zoom',
  GOOGLE_MEET = 'google_meet',
  MICROSOFT_TEAMS = 'microsoft_teams',
}

@Schema({ timestamps: true })
export class Meeting {
  @Prop({ required: true, index: true })
  userId!: string;

  @Prop({ required: true })
  title!: string;

  @Prop({ required: true, enum: MeetingPlatform })
  platform!: MeetingPlatform;

  @Prop({ required: true })
  link!: string;

  @Prop()
  meetingId?: string;

  @Prop()
  passcode?: string;

  @Prop({ required: true })
  scheduledAt!: Date;

  @Prop()
  notes?: string;
}

export const MeetingSchema = SchemaFactory.createForClass(Meeting);
